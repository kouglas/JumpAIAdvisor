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
        guard !content.isEmpty, var conversation = currentConversation else { return }
        
        // Add user message
        let userMessage = Message(content: content, isUser: true)
        conversation.messages.append(userMessage)
        
        // Add thinking message
        let thinkingMessage = Message(content: "", isUser: false, isThinking: true)
        conversation.messages.append(thinkingMessage)
        
        // Update conversation title if it's the first message
        if conversation.messages.count == 2 {
            conversation.title = String(content.prefix(30)) + (content.count > 30 ? "..." : "")
        }
        
        conversation.updatedAt = Date()
        updateConversation(conversation)
        
        // Start streaming response
        isLoading = true
        streamingContent = ""
        HapticFeedback.tick()
        
        // Get all messages except the thinking one
        let messagesForAPI = conversation.messages.filter { !$0.isThinking }
        
        openAIService.streamChatCompletion(
            messages: messagesForAPI,
            onReceive: { [weak self] token in
                guard let self = self else { return }
                
                // First token received
                if self.streamingContent.isEmpty {
                    HapticFeedback.tick()
                    
                    // Remove thinking message and add AI message
                    if var updatedConversation = self.currentConversation {
                        updatedConversation.messages.removeAll { $0.isThinking }
                        let aiMessage = Message(content: token, isUser: false)
                        updatedConversation.messages.append(aiMessage)
                        self.updateConversation(updatedConversation)
                    }
                } else {
                    // Append token to existing message
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
                self?.isLoading = false
                self?.streamingContent = ""
            },
            onError: { [weak self] error in
                guard let self = self else { return }
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                
                // Remove thinking message on error
                if var updatedConversation = self.currentConversation {
                    updatedConversation.messages.removeAll { $0.isThinking }
                    self.updateConversation(updatedConversation)
                }
                
                HapticFeedback.error()
            }
        )
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
