import Foundation

public enum PointDisplay: Equatable, Sendable {
    case regular(home: String, away: String)
    case deuce
    case advantage(TeamSide)
    case tiebreak(home: Int, away: Int)
}

public enum ScoreFormatter {
    public static func pointDisplay(for state: MatchState, loveWord: String = "0") -> PointDisplay {
        if state.currentGame.isTiebreak {
            return .tiebreak(
                home: state.currentGame.rawPoints.home,
                away: state.currentGame.rawPoints.away
            )
        }

        let points = state.currentGame.rawPoints
        if state.format.gameScoring == .advantage,
           points.home >= 3,
           points.away >= 3 {
            if points.home == points.away { return .deuce }
            return .advantage(points.home > points.away ? .home : .away)
        }

        return .regular(
            home: regularPoint(points.home, loveWord: loveWord),
            away: regularPoint(points.away, loveWord: loveWord)
        )
    }

    public static func spokenScore(for state: MatchState, locale: Locale = .current) -> String {
        switch pointDisplay(for: state, loveWord: locale.language.languageCode?.identifier == "zh" ? "零" : "love") {
        case let .regular(home, away):
            return "\(home)–\(away)"
        case .deuce:
            return locale.language.languageCode?.identifier == "zh" ? "平分" : "Deuce"
        case let .advantage(side):
            let name = state.teams[side].displayName
            return locale.language.languageCode?.identifier == "zh" ? "\(name) 占先" : "Advantage \(name)"
        case let .tiebreak(home, away):
            return "\(home)–\(away)"
        }
    }

    private static func regularPoint(_ rawPoint: Int, loveWord: String) -> String {
        switch rawPoint {
        case 0: loveWord
        case 1: "15"
        case 2: "30"
        default: "40"
        }
    }
}
