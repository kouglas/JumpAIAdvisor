import Foundation

struct OpenAIConfig {
    static let apiKey = "YOUR_OPENAI_API_KEY" // Replace with your OpenAI API key
    static let baseURL = "https://api.openai.com/v1"
    static let model = "gpt-4" // or "gpt-3.5-turbo"
    static let streamEndpoint = "/chat/completions"
}

enum OpenAIError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case streamError(String)
    case networkError(Error)
}
