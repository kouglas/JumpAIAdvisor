//
//  ContentView.swift
//  JumpAIAdvisor
//
//  Created by Kari Douglas on 5/10/25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var chatManager: ChatManager
        @State private var messageText = ""
        @State private var textEditorHeight: CGFloat = 44
        @FocusState private var isInputFocused: Bool
        @State private var showConversationList = false
        @State private var showRealTimeChat = false
//        @State private var keyboardHeight: CGFloat = 0
        
        var body: some View {
            NavigationStack {
                ZStack {
                    // Radial animated background
//                    RadialAnimatedBackground()
                    LinearGradient(
                                       colors: [
                                           Color(red: 0.1, green: 0.1, blue: 0.2),
                                           Color(red: 0.05, green: 0.05, blue: 0.15)
                                       ],
                                       startPoint: .top,
                                       endPoint: .bottom
                                   )
                                   .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Centered navigation bar
                        CenteredNavigationBar(
                            onMenuTap: { showConversationList = true }
                        )
                        
                        // Chat messages in scroll view
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(chatManager.currentConversation?.messages ?? []) { message in
                                        MessageBubbleView(message: message)
                                            .id(message.id)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .padding(.bottom, 16)
                            }
                            .onChange(of: chatManager.currentConversation?.messages.count) { _ in
                                withAnimation(.spring(response: 0.3)) {
                                    proxy.scrollTo(chatManager.currentConversation?.messages.last?.id, anchor: .bottom)
                                }
                            }
                        }
                        
                        // Input area with all buttons
                        InputArea(
                            messageText: $messageText,
                            textEditorHeight: $textEditorHeight,
                            isInputFocused: _isInputFocused,
                            onSend: {
                                let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmedText.isEmpty {
                                    chatManager.sendMessage(trimmedText)
                                    messageText = ""
                                    textEditorHeight = 44
                                    isInputFocused = false
                                }
                            },
                            onConversationTap: {
                                showConversationList = true
                            },
                            onVoiceTap: {
                                showRealTimeChat = true
                            }
                        )
                        .background(Color.clear) // Ensure background doesn't interfere
                    }
                }
                .navigationBarHidden(true)
                .ignoresSafeArea(.keyboard) // Important: Don't let keyboard push everything up
                .sheet(isPresented: $showConversationList) {
                    ConversationListView(chatManager: chatManager)
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(30)
                }
                .fullScreenCover(isPresented: $showRealTimeChat) {
                    RealTimeChatView()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        withAnimation(.easeOut(duration: 0.25)) {
//                            keyboardHeight = keyboardFrame.height
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    withAnimation(.easeOut(duration: 0.25)) {
//                        keyboardHeight = 0
                    }
                }
            }
        }
    }


struct MessageBubbleView: View {
    let message: Message
    @State private var displayedText = ""
    @State private var isTyping = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isUser {
                // AI Avatar with proper spacing
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.8), Color.blue],
                            center: .center,
                            startRadius: 1,
                            endRadius: 16
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "brain")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 16) // Add left padding
            } else {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Message bubble
                if message.content.contains("Error:") {
                    // Error message styling
                    Text(message.content)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.red.opacity(0.8))
                        }
                } else {
                    // Normal message
                    Text(displayedText.isEmpty ? message.content : displayedText)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(message.isUser ? Color.blue : Color.gray.opacity(0.3))
                        }
                }
                
                // Action buttons for AI messages
                if !message.isUser && !message.content.isEmpty && !message.content.contains("Error:") {
                    HStack(spacing: 16) {
                        Button(action: {
                            UIPasteboard.general.string = message.content
                            HapticFeedback.success()
                        }) {
                            Label("Copy", systemImage: "doc.on.clipboard")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: {
                            // Play action
                        }) {
                            Label("Play", systemImage: "play.circle")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.leading, 16)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isUser ? .trailing : .leading)
            
            if message.isUser {
                // User Avatar with proper spacing
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.8), Color.pink],
                            center: .center,
                            startRadius: 1,
                            endRadius: 16
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 16) // Add right padding
            } else {
                Spacer()
            }
        }
        .onAppear {
            // Start typing animation for AI messages
            if !message.isUser && displayedText.isEmpty && !message.content.contains("Error:") {
                startTypingAnimation()
            } else {
                displayedText = message.content
            }
        }
    }
    
    private func startTypingAnimation() {
        // Animation code here
        displayedText = message.content // For now, show all at once
    }
}


// Centered Navigation Bar
struct CenteredNavigationBar: View {
    let onMenuTap: () -> Void
    
    var body: some View {
        ZStack {
            // Title in exact center
            Text("Chat")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(maxWidth: .infinity)
            
            // Menu button on left
            HStack {
                Button(action: onMenuTap) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.white.opacity(0.1), .clear],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        )
                }
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}

// Fixed Input Area
struct InputArea: View {
    @Binding var messageText: String
     @Binding var textEditorHeight: CGFloat
     @FocusState var isInputFocused: Bool
     let onSend: () -> Void
     let onConversationTap: () -> Void
     let onVoiceTap: () -> Void
     
     var body: some View {
         VStack(spacing: 0) {
             // Add a separator line
             Rectangle()
                 .fill(Color.gray.opacity(0.3))
                 .frame(height: 1)
             
             HStack(alignment: .bottom, spacing: 8) {
                 // Animated border input field
                 AnimatedBorderInput(
                     text: $messageText,
                     height: $textEditorHeight,
                     isFocused: _isInputFocused
                 )
                 
                 // Button group on the right
                 HStack(spacing: 8) {
                     // Conversation button
                     WeightedButton(
                         icon: "bubble.left.bubble.right",
                         action: onConversationTap,
                         gradient: LinearGradient(
                             colors: [.blue, .purple],
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing
                         )
                     )
                     
                     // Send button
                     AnimatedSendButton(
                         isEnabled: !messageText.isEmpty,
                         action: onSend
                     )
                     
                     // Voice button
                     WeightedButton(
                         icon: "mic.fill",
                         action: onVoiceTap,
                         gradient: LinearGradient(
                             colors: [.purple, .pink],
                             startPoint: .topLeading,
                             endPoint: .bottomTrailing
                         )
                     )
                 }
             }
             .padding(.horizontal, 16)
             .padding(.vertical, 12)
             .background {
                 Rectangle()
                     .fill(.ultraThickMaterial)
             }
         }
     }
}

// Weighted Button with depth
struct WeightedButton: View {
    let icon: String
    let action: () -> Void
    let gradient: LinearGradient
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                action()
                HapticFeedback.impact(style: .medium)
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(gradient)
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(1)
                        )
//                        .shadow(color: gradient.stops.first?.color.opacity(0.4) ?? .blue.opacity(0.4), radius: 8, y: 4)
                }
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .offset(y: isPressed ? 2 : 0)
        }
    }
}

// Animated Border Input with circling gradient
struct AnimatedBorderInput: View {
    @Binding var text: String
    @Binding var height: CGFloat
    @FocusState var isFocused: Bool
    
    @State private var rotation = 0.0
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Height measurement
            Text(text.isEmpty ? "Message" : text)
                .font(.system(size: 17))
                .foregroundColor(.clear)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(GeometryReader { geometry in
                    Color.clear.preference(
                        key: ViewHeightKey.self,
                        value: geometry.size.height
                    )
                })
            
            // Text editor
            TextEditor(text: $text)
                .font(.system(size: 17))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .focused($isFocused)
                .frame(height: min(height, 250))
                .scrollContentBackground(.hidden)
                .background {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(.ultraThickMaterial)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    .blue, .purple, .pink, .orange, .yellow, .green, .blue
                                ]),
                                center: .center,
                                angle: .degrees(rotation)
                            ),
                            lineWidth: isFocused ? 3 : 1.5
                        )
                        .opacity(isFocused ? 1 : 0.6)
                }
                
            // Placeholder
            if text.isEmpty {
                Text("Message")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(ViewHeightKey.self) { newHeight in
            height = max(44, min(newHeight, 250))
        }
        .onChange(of: isFocused) { newValue in
            if newValue {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                rotation = 0
            }
        }
    }
}

// Radial Animated Background
struct RadialAnimatedBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Radial sunburst effect
            ForEach(0..<12) { index in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(0.15),
                                Color.orange.opacity(0.1),
                                Color.red.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .center,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: UIScreen.main.bounds.height)
                    .rotationEffect(.degrees(Double(index) * 30))
                    .scaleEffect(x: animate ? 1.5 : 1, y: animate ? 1.2 : 1)
                    .opacity(animate ? 0.6 : 0.3)
            }
            .blur(radius: 30)
            
            // Glowing center
            RadialGradient(
                colors: [
                    Color.yellow.opacity(0.2),
                    Color.orange.opacity(0.15),
                    Color.red.opacity(0.1),
                    Color.clear
                ],
                center: .center,
                startRadius: animate ? 50 : 100,
                endRadius: animate ? 300 : 400
            )
            .scaleEffect(animate ? 1.3 : 1.0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate = true
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
                    .stroke(Gradients.primary, lineWidth: 2)
                    .scaleEffect(rippleScale)
                    .opacity(isAnimating ? 0 : 0.7)
                    
                Circle()
                    .stroke(Gradients.primary, lineWidth: 2)
                    .scaleEffect(rippleScale * 1.2)
                    .opacity(isAnimating ? 0 : 0.5)
                
                // Main button
                Circle()
                    .fill(Gradients.primary)
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

// MARK: -  Chat View
struct ChatView: View {
    @ObservedObject var chatManager: ChatManager
    @State private var messageText = ""
    @State private var textEditorHeight: CGFloat = 44
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages with  scroll behavior
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(chatManager.currentConversation?.messages ?? []) { message in
                            ScrollAwareMessageBubble(message: message)
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
            
            //  input area
            MessageInputView(
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

// MARK: -  Message Input View
struct MessageInputView: View {
    @Binding var messageText: String
    @Binding var textEditorHeight: CGFloat
    @FocusState var isInputFocused: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            InputField(
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
                        .fill(Gradients.glass)
                        .frame(height: 1)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
        }
    }
}


//#Preview {
//    ContentView(chatManager: ChatManager())
//    .preferredColorScheme(.dark)
//}
