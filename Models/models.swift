//
//  JumpAIAdvisorApp.swift
//  JumpAIAdvisor
//
//  Created by Kari Douglas on 5/10/25.
//


import Foundation

struct Message: Identifiable, Codable {
    let id = UUID()
    var content: String
    let isUser: Bool
    let timestamp: Date
    var isThinking: Bool = false
    
    init(content: String, isUser: Bool, timestamp: Date = Date(), isThinking: Bool = false) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.isThinking = isThinking
    }
}

struct Conversation: Identifiable, Codable {
    let id = UUID()
    var title: String
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    
    init(title: String = "New Chat", messages: [Message] = [], createdAt: Date = Date()) {
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
