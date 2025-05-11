import Foundation
import SwiftUI

class ChatManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var isLoading = false
    @Published var streamingContent = ""
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let conversationsKey = "SavedConversations"
    private let openAIService = OpenAIService()
    
    init() {
        loadConversations()
        if conversations.isEmpty {
            createNewConversation()
        } else {
            currentConversation = conversations.first
        }
    }
    
    func createNewConversation() {
        let newConversation = Conversation()
        conversations.insert(newConversation, at: 0)
        currentConversation = newConversation
        saveConversations()
    }
    
    func selectConversation(_ conversation: Conversation) {
        currentConversation = conversation
    }
    
    func sendMessage(_ content: String) {
        print("🔍 Debug: Sending message: \(content)")
        
        guard !content.isEmpty, var conversation = currentConversation else {
            print("❌ Debug: Empty content or no conversation")
            return
        }
        
        // Add user message
        let userMessage = Message(content: content, isUser: true)
        conversation.messages.append(userMessage)
        
        // Add thinking message
        let thinkingMessage = Message(content: "", isUser: false, isThinking: true)
        conversation.messages.append(thinkingMessage)
        
        // Update conversation
        conversation.updatedAt = Date()
        updateConversation(conversation)
        
        // Start streaming response
        isLoading = true
        streamingContent = ""
        HapticFeedback.tick()
        
        print("🔍 Debug: Starting API call with \(conversation.messages.count) messages")
        
        openAIService.streamChatCompletion(
            messages: conversation.messages.filter { !$0.isThinking },
            onReceive: { [weak self] token in
                print("🔍 Debug: Received token: \(token)")
                
                guard let self = self else { return }
                
                if self.streamingContent.isEmpty {
                    HapticFeedback.tick()
                    
                    if var updatedConversation = self.currentConversation {
                        updatedConversation.messages.removeAll { $0.isThinking }
                        let aiMessage = Message(content: token, isUser: false)
                        updatedConversation.messages.append(aiMessage)
                        self.updateConversation(updatedConversation)
                    }
                } else {
                    if var updatedConversation = self.currentConversation,
                       let lastIndex = updatedConversation.messages.lastIndex(where: { !$0.isUser && !$0.isThinking }) {
                        var message = updatedConversation.messages[lastIndex]
                        message.content += token
                        updatedConversation.messages[lastIndex] = message
                        self.updateConversation(updatedConversation)
                    }
                }
                
                self.streamingContent += token
            },
            onComplete: { [weak self] in
                print("✅ Debug: Stream completed")
                self?.isLoading = false
                self?.streamingContent = ""
            },
            onError: { [weak self] error in
                print("❌ Debug: Error occurred: \(error.localizedDescription)")
                
                guard let self = self else { return }
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                
                // Remove thinking message on error
                if var updatedConversation = self.currentConversation {
                    updatedConversation.messages.removeAll { $0.isThinking }
                    
                    // Add error message
                    let errorMessage = Message(
                        content: "Error: \(error.localizedDescription)",
                        isUser: false
                    )
                    updatedConversation.messages.append(errorMessage)
                    self.updateConversation(updatedConversation)
                }
                
                HapticFeedback.error()
            }
        )
    }
    private func handleError(_ errorMessage: String) {
        self.isLoading = false
        
        // Remove thinking message and add error message
        if var updatedConversation = self.currentConversation {
            updatedConversation.messages.removeAll { $0.isThinking }
            
            let errorMsg = Message(
                content: errorMessage,
                isUser: false
            )
            updatedConversation.messages.append(errorMsg)
            self.updateConversation(updatedConversation)
        }
        
        HapticFeedback.error()
    }
    
    private func updateConversation(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
            currentConversation = conversation
            saveConversations()
        }
    }
    
    private func saveConversations() {
        if let encoded = try? JSONEncoder().encode(conversations) {
            userDefaults.set(encoded, forKey: conversationsKey)
        }
    }
    
    private func loadConversations() {
        if let data = userDefaults.data(forKey: conversationsKey),
           let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decoded
        }
    }
    
    func cancelCurrentRequest() {
        openAIService.cancelStream()
        isLoading = false
    }
}
