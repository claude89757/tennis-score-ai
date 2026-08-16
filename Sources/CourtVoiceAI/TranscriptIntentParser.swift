import Foundation
import CourtVoiceCore

public struct TranscriptIntentParser: Sendable {
    public init() {}

    public func parse(_ transcript: String) -> IntentCandidate {
        let normalized = normalize(transcript)
        guard normalized.isEmpty == false else {
            return candidate(.unknown, normalized, 0, true)
        }

        if containsAny(normalized, ["如果", "要是", "假如", "would be", "will be", "if "]) {
            return candidate(.discussion, normalized, 0.98, true)
        }

        if containsAny(normalized, ["撤销", "退回上一分", "回退", "undo", "take that back"]) {
            return candidate(.undo, normalized, 0.98, false)
        }

        if containsAny(normalized, ["重打", "这一分不算", "let", "replay the point"]) {
            return candidate(.replayPoint, normalized, 0.97, false)
        }

        if containsAny(normalized, ["暂停", "pause"]) {
            return candidate(.pause, normalized, 0.99, false)
        }

        if containsAny(normalized, ["继续比赛", "恢复比赛", "resume"]) {
            return candidate(.resume, normalized, 0.99, false)
        }

        if containsAny(normalized, ["平分", "deuce", "40 all", "forty all"]) {
            return candidate(.deuce, normalized, 0.99, false)
        }

        if containsAny(normalized, ["发球方占先", "发球占先", "advantage server", "ad in", "advantage in"]) {
            return candidate(.advantageServer, normalized, 0.98, false)
        }

        if containsAny(normalized, ["接发方占先", "接发占先", "advantage receiver", "ad out", "advantage out"]) {
            return candidate(.advantageReceiver, normalized, 0.98, false)
        }

        let correctionLanguage = containsAny(
            normalized,
            ["不是", "应该", "改成", "纠正", "actually", "instead", "correction"]
        )
        let scoreText = correctionLanguage ? correctionSuffix(from: normalized) : normalized
        if let score = parseScorePair(scoreText) {
            return candidate(
                .reportedScore(server: score.0, receiver: score.1),
                normalized,
                score.2,
                correctionLanguage || score.2 < 0.92
            )
        }

        if containsAny(normalized, ["我得分", "左边得分", "home point"]) {
            return candidate(.awardPoint(.home), normalized, 0.78, true)
        }

        if containsAny(normalized, ["你得分", "右边得分", "away point"]) {
            return candidate(.awardPoint(.away), normalized, 0.78, true)
        }

        return candidate(.unknown, normalized, 0.15, true)
    }

    private func candidate(
        _ intent: ScoreIntent,
        _ text: String,
        _ confidence: Double,
        _ requiresConfirmation: Bool
    ) -> IntentCandidate {
        IntentCandidate(
            intent: intent,
            normalizedText: text,
            confidence: confidence,
            requiresConfirmation: requiresConfirmation,
            parserID: "deterministic.v1"
        )
    }

    private func parseScorePair(_ text: String) -> (ReportedPoint, ReportedPoint, Double)? {
        let allScores: [(String, ReportedPoint)] = [
            ("零", .love), ("十五", .fifteen), ("三十", .thirty), ("四十", .forty),
            ("love", .love), ("fifteen", .fifteen), ("thirty", .thirty), ("forty", .forty),
            ("0", .love), ("15", .fifteen), ("30", .thirty), ("40", .forty)
        ].sorted { $0.0.count > $1.0.count }
        for (token, point) in allScores where text.contains(token + "平") || text.contains(token + " all") {
            return (point, point, 0.96)
        }

        let canonical = text
            .replacingOccurrences(of: "比分", with: " ")
            .replacingOccurrences(of: "比", with: "-")
            .replacingOccurrences(of: "：", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " to ", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")

        let tokens = canonical
            .split(whereSeparator: { $0 == "-" || $0 == "/" || $0 == "," })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        if tokens.count == 2,
           let first = point(from: tokens[0]),
           let second = point(from: tokens[1]) {
            return (first, second, 0.97)
        }

        let words = canonical.split(separator: " ").map(String.init)
        if words.count >= 2 {
            for index in 0..<(words.count - 1) {
                if let first = point(from: words[index]),
                   let second = point(from: words[index + 1]) {
                    return (first, second, 0.93)
                }
            }
        }

        let compactChinese: [(String, ReportedPoint)] = [
            ("零", .love), ("十五", .fifteen), ("三十", .thirty), ("四十", .forty)
        ]
        for (leftText, leftPoint) in compactChinese {
            for (rightText, rightPoint) in compactChinese {
                if canonical.contains(leftText + rightText) {
                    return (leftPoint, rightPoint, 0.9)
                }
            }
        }

        if let embedded = lastTwoPointTokens(in: canonical) {
            return (embedded.0, embedded.1, 0.94)
        }

        return nil
    }

    private func lastTwoPointTokens(in text: String) -> (ReportedPoint, ReportedPoint)? {
        let lexicon: [(String, ReportedPoint)] = [
            ("fifteen", .fifteen), ("thirty", .thirty), ("forty", .forty), ("love", .love),
            ("十五", .fifteen), ("三十", .thirty), ("四十", .forty),
            ("15", .fifteen), ("30", .thirty), ("40", .forty),
            ("零", .love), ("0", .love),
        ].sorted { $0.0.count > $1.0.count }

        var found: [ReportedPoint] = []
        var index = text.startIndex
        while index < text.endIndex {
            let rest = String(text[index...])
            if let match = lexicon.first(where: { rest.hasPrefix($0.0) }) {
                found.append(match.1)
                index = text.index(index, offsetBy: match.0.count)
            } else {
                index = text.index(after: index)
            }
        }

        guard found.count >= 2 else { return nil }
        return (found[found.count - 2], found[found.count - 1])
    }

    private func point(from token: String) -> ReportedPoint? {
        let cleaned = token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "分", with: "")

        switch cleaned {
        case "0", "零", "love", "nil": return .love
        case "15", "十五", "fifteen": return .fifteen
        case "30", "三十", "thirty": return .thirty
        case "40", "四十", "forty": return .forty
        default: return nil
        }
    }

    private func correctionSuffix(from text: String) -> String {
        let markers = ["应该", "改成", "其实", "actually", "instead", "是"]
        var best: String.Index?
        for marker in markers {
            if let range = text.range(of: marker, options: .backwards),
               best == nil || range.upperBound > best! {
                best = range.upperBound
            }
        }
        guard let best else { return text }
        return String(text[best...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "，", with: " ")
            .replacingOccurrences(of: "。", with: " ")
            .replacingOccurrences(of: "！", with: " ")
            .replacingOccurrences(of: "？", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsAny(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains(where: text.contains)
    }
}
