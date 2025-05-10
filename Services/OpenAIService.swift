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
        
        streamTask = session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    onError(OpenAIError.networkError(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    onError(OpenAIError.invalidResponse)
                }
                return
            }
            
            if httpResponse.statusCode != 200 {
                if let data = data,
                   let errorMessage = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        onError(OpenAIError.apiError(errorMessage))
                    }
                } else {
                    DispatchQueue.main.async {
                        onError(OpenAIError.apiError("HTTP \(httpResponse.statusCode)"))
                    }
                }
                return
            }
            
            guard let data = data else { return }
            
            self?.handleStreamData(data, onReceive: onReceive, onComplete: onComplete, onError: onError)
        }
        
        streamTask?.resume()
    }
    
    private func handleStreamData(
        _ data: Data,
        onReceive: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        let lines = String(data: data, encoding: .utf8)?.components(separatedBy: "\n") ?? []
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString == "[DONE]" {
                    DispatchQueue.main.async {
                        onComplete()
                    }
                    return
                }
                
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let delta = firstChoice["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    
                    DispatchQueue.main.async {
                        onReceive(content)
                    }
                }
            }
        }
    }
    
    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
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
