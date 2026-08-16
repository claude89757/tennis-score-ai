import Foundation

struct DeepSeekScoreReasoningClient: ScoreReasoningClient {
  let apiKey: String
  let endpoint: URL
  let model: String
  let reasoningEffort: String

  func streamProposal(
    transcript: String,
    matchContext: String,
    onEvent: @escaping @Sendable (ScoreReasoningEvent) -> Void
  ) async throws -> String {
    guard endpoint.scheme?.lowercased() == "https" else {
      throw ScoreReasoningError.invalidEndpoint
    }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": model,
      "stream": true,
      "reasoning_effort": reasoningEffort,
      "thinking": ["type": "enabled"],
      "messages": [
        ["role": "system", "content": Self.systemPrompt],
        [
          "role": "user",
          "content": """
            Official match context:
            \(matchContext)

            Spoken transcript:
            \(transcript)
            """,
        ],
      ],
    ])

    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) == false {
      throw ScoreReasoningError.httpStatus(http.statusCode)
    }

    var answer = ""
    var buffer = ""
    for try await byte in bytes {
      buffer.append(Character(UnicodeScalar(byte)))
      while let separator = buffer.range(of: "\n\n") {
        let block = String(buffer[buffer.startIndex..<separator.lowerBound])
        buffer.removeSubrange(buffer.startIndex..<separator.upperBound)
        try Task.checkCancellation()
        if let delta = Self.parseSSEBlock(block) {
          if let thinking = delta.reasoningContent, thinking.isEmpty == false {
            onEvent(.thinkingDelta(thinking))
          }
          if let content = delta.content, content.isEmpty == false {
            answer += content
            onEvent(.answerDelta(content))
          }
        }
      }
    }

    if answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      throw ScoreReasoningError.emptyAnswer
    }
    return answer
  }

  private static let systemPrompt = """
    You are an untrusted tennis score-intent sensor for CourtVoice.
    You never change the official scoreboard. Think through what the caller said, then output one JSON object and nothing else.
    Schema:
    {"intent":"reported_score|award_point|undo|deuce|advantage_server|advantage_receiver|replay_point|pause|resume|discussion|unknown","server":"love|fifteen|thirty|forty","receiver":"love|fifteen|thirty|forty","side":"home|away","confidence":0.0,"summary":"short reason"}
    Rules:
    - reported_score uses server-then-receiver order.
    - Use discussion for hypothetical, joke, or non-scoring talk.
    - Use unknown when the transcript is not a tennis score action.
    - Do not invent a point if the official context already matches the spoken score.
    """

  private static func parseSSEBlock(_ block: String) -> StreamDelta.Choice.Delta? {
    let payload = block
      .split(separator: "\n")
      .compactMap { line -> String? in
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("data:") else { return nil }
        return String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
      }
      .joined()

    guard payload.isEmpty == false, payload != "[DONE]",
      let data = payload.data(using: .utf8)
    else {
      return nil
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try? decoder.decode(StreamDelta.self, from: data).choices.first?.delta
  }
}

private struct StreamDelta: Decodable {
  struct Choice: Decodable {
    struct Delta: Decodable {
      var content: String?
      var reasoningContent: String?
    }

    var delta: Delta
  }

  var choices: [Choice]
}
