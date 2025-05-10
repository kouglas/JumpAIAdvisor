//
//  ContentView.swift
//  JumpAIAdvisor
//
//  Created by Kari Douglas on 5/10/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var chatManager = ChatManager()
        @State private var showConversationList = false
        @State private var showRealTimeChat = false
        @Namespace private var animation
        
        var body: some View {
            NavigationStack {
                ZStack {
                    // Modern gradient background
                    LinearGradient(
                        colors: [Color.black, Color.black.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    
                    // Chat interface
                    ModernChatView(chatManager: chatManager)
                        .navigationBarHidden(true)
                    
                    // Custom navigation bar
                    VStack {
                        ModernNavigationBar(
                            title: "Chat",
                            leftButton: AnyView(
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showConversationList = true
                                    }
                                }) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(ModernGradients.primary)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                        )
                                }
                            )
                        )
                        
                        Spacer()
                    }
                    
                    // Floating voice button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            AnimatedVoiceButton {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showRealTimeChat = true
                                }
                            }
                            .padding(.trailing, 24)
                            .padding(.bottom, 100)
                        }
                    }
                }
                .sheet(isPresented: $showConversationList) {
                    ModernConversationListView(chatManager: chatManager)
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(30)
                        .presentationBackground(.ultraThinMaterial)
                }
                .fullScreenCover(isPresented: $showRealTimeChat) {
                    ModernRealTimeChatView()
                        .presentationBackground(.black)
                }
            }
        }
}



// MARK: - Animated Voice Button
struct AnimatedVoiceButton: View {
    let action: () -> Void
    @State private var isAnimating = false
    @State private var rippleScale: CGFloat = 0.8
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Ripple effect
                Circle()
                    .stroke(ModernGradients.primary, lineWidth: 2)
                    .scaleEffect(rippleScale)
                    .opacity(isAnimating ? 0 : 0.7)
                    
                Circle()
                    .stroke(ModernGradients.primary, lineWidth: 2)
                    .scaleEffect(rippleScale * 1.2)
                    .opacity(isAnimating ? 0 : 0.5)
                
                // Main button
                Circle()
                    .fill(ModernGradients.primary)
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "waveform")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .symbolEffect(.bounce, value: isAnimating)
                    }
                    .shadow(color: .purple.opacity(0.5), radius: 10, y: 5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                isAnimating = true
                rippleScale = 1.5
            }
        }
    }
}

// MARK: - Modern Chat View
struct ModernChatView: View {
    @ObservedObject var chatManager: ChatManager
    @State private var messageText = ""
    @State private var textEditorHeight: CGFloat = 44
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages with modern scroll behavior
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chatManager.currentConversation?.messages ?? []) { message in
                            ModernMessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.top, 80)
                    .padding(.bottom, 20)
                }
                .onChange(of: chatManager.currentConversation?.messages.count) { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        proxy.scrollTo(chatManager.currentConversation?.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            // Modern input area
            ModernMessageInputView(
                messageText: $messageText,
                textEditorHeight: $textEditorHeight,
                isInputFocused: _isInputFocused,
                onSend: {
                    let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedText.isEmpty {
                        chatManager.sendMessage(trimmedText)
                        messageText = ""
                        textEditorHeight = 44
                    }
                }
            )
        }
        .background(Color.black.opacity(0.95))
        .onTapGesture {
            isInputFocused = false
        }
    }
}

// MARK: - Modern Message Input View
struct ModernMessageInputView: View {
    @Binding var messageText: String
    @Binding var textEditorHeight: CGFloat
    @FocusState var isInputFocused: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ModernInputField(
                text: $messageText,
                height: $textEditorHeight,
                isFocused: _isInputFocused,
                placeholder: "Message"
            )
            
            AnimatedSendButton(
                isEnabled: !messageText.isEmpty,
                action: onSend
            )
            .offset(y: -4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.ultraThickMaterial)
                .overlay {
                    Rectangle()
                        .fill(ModernGradients.glass)
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
        }
    }
}
//#Preview {
//    ContentView()
//    .preferredColorScheme(.dark)
//}
