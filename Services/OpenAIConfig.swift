import Foundation

struct OpenAIConfig {
    static var apiKey: String {
           // Read from Info.plist
           guard let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
                 !key.isEmpty,
                 key != "YOUR_API_KEY_HERE" else {
               // In a production app, you might want to handle this more gracefully
               // For example, show an alert to the user or provide a way to enter the key
               print("⚠️ OpenAI API key not found or not configured in Info.plist")
               print("Please add your OpenAI API key to Info.plist with the key 'OPENAI_API_KEY'")
               
               // Return empty string and handle in your service layer
               return ""
           }
           return key
       }
       
       static let baseURL = "https://api.openai.com/v1"
       static let model = "gpt-3.5-turbo" // or "gpt-3.5-turbo"
       static let streamEndpoint = "/chat/completions"
       
       // Helper to check if API key is properly configured
       static var hasValidAPIKey: Bool {
           let key = apiKey
           return !key.isEmpty && key != "YOUR_API_KEY_HERE"
       }
}

enum OpenAIError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case streamError(String)
    case networkError(Error)
    case missingAPIKey
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let message):
            return "API Error: \(message)"
        case .streamError(let message):
            return "Stream Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .missingAPIKey:
            return "OpenAI API key is missing. Please add it to Info.plist"
        }
    }
}
