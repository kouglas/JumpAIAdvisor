import Foundation
import SwiftUI

class OpenAIService {
    private let session = URLSession.shared
    private var streamTask: URLSessionDataTask?
    
    func streamChatCompletion(
        messages: [Message],
        onReceive: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        print("🔍 Debug: Starting API call")
        print("🔍 Debug: API Key present: \(OpenAIConfig.hasValidAPIKey)")
        
        guard OpenAIConfig.hasValidAPIKey else {
            onError(OpenAIError.missingAPIKey)
            return
        }
        
        guard let url = URL(string: OpenAIConfig.baseURL + OpenAIConfig.streamEndpoint) else {
            onError(OpenAIError.invalidURL)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let openAIMessages = messages.map { message in
            [
                "role": message.isUser ? "user" : "assistant",
                "content": message.content
            ]
        }
        
        let requestBody: [String: Any] = [
            "model": OpenAIConfig.model,
            "messages": openAIMessages,
            "stream": true,
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            onError(error)
            return
        }
        
        // Use URLSessionDataDelegate for streaming
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: StreamingDelegate(
            onReceive: onReceive,
            onComplete: onComplete,
            onError: onError
        ), delegateQueue: nil)
        
        streamTask = session.dataTask(with: request)
        streamTask?.resume()
    }
    
    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
    }
}

// Streaming delegate to handle SSE data
private class StreamingDelegate: NSObject, URLSessionDataDelegate {
    private let onReceive: (String) -> Void
    private let onComplete: () -> Void
    private let onError: (Error) -> Void
    private var buffer = ""
    
    init(onReceive: @escaping (String) -> Void,
         onComplete: @escaping () -> Void,
         onError: @escaping (Error) -> Void) {
        self.onReceive = onReceive
        self.onComplete = onComplete
        self.onError = onError
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text
        
        // Process complete lines
        let lines = buffer.components(separatedBy: "\n")
        for i in 0..<lines.count - 1 {
            processLine(lines[i])
        }
        
        // Keep the last incomplete line in the buffer
        buffer = lines.last ?? ""
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.onError(error)
            }
        } else {
            // Process any remaining data in buffer
            if !buffer.isEmpty {
                processLine(buffer)
            }
            DispatchQueue.main.async {
                self.onComplete()
            }
        }
    }
    
    private func processLine(_ line: String) {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip empty lines
        if trimmedLine.isEmpty {
            return
        }
        
        // Check for completion
        if trimmedLine == "data: [DONE]" {
            return
        }
        
        // Extract JSON from SSE format
        if trimmedLine.hasPrefix("data: ") {
            let jsonString = String(trimmedLine.dropFirst(6))
            
            guard let jsonData = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let delta = firstChoice["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                return
            }
            
            DispatchQueue.main.async {
                self.onReceive(content)
            }
        }
    }
}

// Simple non-streaming version for voice chat
extension OpenAIService {
    func getChatCompletion(
        messages: [Message],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: OpenAIConfig.baseURL + OpenAIConfig.streamEndpoint) else {
            completion(.failure(OpenAIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let openAIMessages = messages.map { message in
            [
                "role": message.isUser ? "user" : "assistant",
                "content": message.content
            ]
        }
        
        let requestBody: [String: Any] = [
            "model": OpenAIConfig.model,
            "messages": openAIMessages,
            "temperature": 0.7,
            "max_tokens": 500
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(OpenAIError.networkError(error)))
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async {
                    completion(.failure(OpenAIError.invalidResponse))
                }
                return
            }
            
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                DispatchQueue.main.async {
                    completion(.failure(OpenAIError.apiError(message)))
                }
                return
            }
            
            if let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                DispatchQueue.main.async {
                    completion(.success(content))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(OpenAIError.invalidResponse))
                }
            }
        }.resume()
    }
}
