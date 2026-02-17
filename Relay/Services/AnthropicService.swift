import Foundation

final class AnthropicService: LLMService, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }

    func streamCompletion(
        messages: [ChatMessage],
        model: String,
        apiKey: String,
        tools: [ToolDefinition] = [],
        forceToolName: String? = nil
    ) -> AsyncThrowingStream<StreamToken, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("messages"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    var systemText: String?
                    var conversationMessages: [[String: Any]] = []

                    for msg in messages {
                        if msg.role == "system" {
                            if let existing = systemText {
                                systemText = existing + "\n\n" + msg.content
                            } else {
                                systemText = msg.content
                            }
                            continue
                        }

                        // Anthropic tool result message
                        if let toolCallId = msg.toolCallId {
                            conversationMessages.append([
                                "role": "user",
                                "content": [[
                                    "type": "tool_result",
                                    "tool_use_id": toolCallId,
                                    "content": msg.content
                                ]]
                            ])
                            continue
                        }

                        // Anthropic assistant tool calls
                        if msg.role == "assistant", let toolCalls = msg.toolCalls, !toolCalls.isEmpty {
                            var content: [[String: Any]] = []
                            if !msg.content.isEmpty {
                                content.append(["type": "text", "text": msg.content])
                            }
                            for call in toolCalls {
                                content.append([
                                    "type": "tool_use",
                                    "id": call.id,
                                    "name": call.name,
                                    "input": parseToolInput(call.arguments)
                                ])
                            }
                            conversationMessages.append([
                                "role": "assistant",
                                "content": content
                            ])
                            continue
                        }

                        // Image message
                        if let base64 = msg.imageBase64 {
                            let content: [[String: Any]] = [
                                ["type": "text", "text": msg.content],
                                ["type": "image", "source": [
                                    "type": "base64",
                                    "media_type": "image/jpeg",
                                    "data": base64
                                ]]
                            ]
                            conversationMessages.append([
                                "role": msg.role,
                                "content": content
                            ])
                            continue
                        }

                        // Standard text message
                        conversationMessages.append([
                            "role": msg.role,
                            "content": msg.content
                        ])
                    }

                    var body: [String: Any] = [
                        "model": model,
                        "messages": conversationMessages,
                        "max_tokens": 8192,
                        "stream": true
                    ]
                    if let systemText {
                        body["system"] = systemText
                    }

                    if !tools.isEmpty {
                        body["tools"] = tools.map { tool in
                            [
                                "name": tool.name,
                                "description": tool.description,
                                "input_schema": tool.parameters
                            ] as [String: Any]
                        }
                        if let forceToolName {
                            body["tool_choice"] = [
                                "type": "tool",
                                "name": forceToolName
                            ]
                        }
                    }

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.networkError("Invalid response")
                    }

                    if httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                            if errorBody.count > 500 { break }
                        }

                        switch httpResponse.statusCode {
                        case 401: throw LLMError.invalidAPIKey
                        case 429: throw LLMError.rateLimited
                        default:
                            if let data = errorBody.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let error = json["error"] as? [String: Any],
                               let message = error["message"] as? String {
                                throw LLMError.networkError(message)
                            }
                            throw LLMError.networkError("HTTP \(httpResponse.statusCode)")
                        }
                    }

                    var promptTokens = 0

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))
                        if data == "[DONE]" { break }

                        guard let jsonData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let type = json["type"] as? String else {
                            continue
                        }

                        switch type {
                        case "message_start":
                            if let message = json["message"] as? [String: Any],
                               let usage = message["usage"] as? [String: Any],
                               let inputTokens = usage["input_tokens"] as? Int {
                                promptTokens = inputTokens
                            }
                        case "content_block_start":
                            guard let index = json["index"] as? Int,
                                  let block = json["content_block"] as? [String: Any],
                                  let blockType = block["type"] as? String,
                                  blockType == "tool_use" else { continue }

                            let id = block["id"] as? String
                            let name = block["name"] as? String
                            let arguments = toolInputJSONString(from: block["input"])
                            continuation.yield(.toolCall(index: index, id: id, name: name, arguments: arguments))

                        case "content_block_delta":
                            let index = json["index"] as? Int ?? 0
                            guard let delta = json["delta"] as? [String: Any],
                                  let deltaType = delta["type"] as? String else { continue }

                            switch deltaType {
                            case "text_delta":
                                if let text = delta["text"] as? String {
                                    continuation.yield(.content(text))
                                }
                            case "thinking_delta":
                                if let thinking = delta["thinking"] as? String {
                                    continuation.yield(.reasoning(thinking))
                                }
                            case "input_json_delta":
                                if let partial = delta["partial_json"] as? String {
                                    continuation.yield(.toolCall(index: index, id: nil, name: nil, arguments: partial))
                                }
                            default:
                                break
                            }
                        case "message_delta":
                            if let delta = json["delta"] as? [String: Any],
                               let stopReason = delta["stop_reason"] as? String {
                                continuation.yield(.finishReason(mapStopReason(stopReason)))
                            }

                            if let usage = json["usage"] as? [String: Any],
                               let outputTokens = usage["output_tokens"] as? Int {
                                continuation.yield(.usage(
                                    promptTokens: promptTokens,
                                    completionTokens: outputTokens
                                ))
                            }
                        case "message_stop":
                            break
                        case "error":
                            if let error = json["error"] as? [String: Any],
                               let message = error["message"] as? String {
                                throw LLMError.networkError(message)
                            }
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func parseToolInput(_ arguments: String) -> [String: Any] {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private func toolInputJSONString(from input: Any?) -> String? {
        guard let input else { return nil }
        if let text = input as? String {
            return text
        }
        if let dictionary = input as? [String: Any], dictionary.isEmpty {
            return nil
        }
        guard JSONSerialization.isValidJSONObject(input),
              let data = try? JSONSerialization.data(withJSONObject: input),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }

    private func mapStopReason(_ stopReason: String) -> String {
        switch stopReason {
        case "tool_use": "tool_calls"
        case "end_turn": "stop"
        case "max_tokens": "length"
        default: stopReason
        }
    }
}
