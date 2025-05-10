import SwiftUI
import AVFAudio

// MARK: -  Gradient Definitions
struct Gradients {
    static let primary = LinearGradient(
        colors: [.blue, .purple, .pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let secondary = LinearGradient(
        colors: [.teal, .mint, .cyan],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let accent = LinearGradient(
        colors: [.orange, .red, .pink],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let glass = LinearGradient(
        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Animated Gradient Border Button
struct AnimatedGradientButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var rotation = 0.0
    @State private var isPressed = false
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeIn(duration: 0.1)) {
                    isPressed = false
                }
                action()
                HapticFeedback.impact()
            }
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.blue, .purple, .pink, .blue]),
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: 3
                    )
                    .blur(radius: isPressed ? 4 : 0)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Glass Morphism Card
struct GlassMorphismCard: View {
    let content: AnyView
    var padding: CGFloat = 16
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        Gradients.glass,
                        lineWidth: 1
                    )
            }
    }
}

// MARK: - Animated Send Button
struct AnimatedSendButton: View {
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isEnabled ? Gradients.primary : LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
            }
        }
        .disabled(!isEnabled)
        .onChange(of: isEnabled) { newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAnimating = false
                }
            }
        }
    }
}

// MARK: -  Message Bubble
struct MessageBubble: View {
    let message: Message
    @State private var appeared = false
    @State private var isPlaying = false
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if !message.isUser {
                // AI Avatar
                Circle()
                    .fill(Gradients.primary)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .purple.opacity(0.3), radius: 5)
            }
            
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                if message.isThinking {
                    ThinkingIndicator()
                } else {
                    // Message content with  styling
                    Markdown(text: message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            if message.isUser {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Gradients.primary)
                            } else {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(Gradients.glass, lineWidth: 1)
                                    }
                            }
                        }
                        .foregroundColor(message.isUser ? .white : .primary)
                    
                    // Action buttons for AI messages
                    if !message.isUser && !message.content.isEmpty {
                        HStack(spacing: 16) {
                            ActionButton(icon: "doc.on.doc", title: "Copy") {
                                UIPasteboard.general.string = message.content
                                HapticFeedback.success()
                            }
                            
                            ActionButton(
                                icon: isPlaying ? "stop.circle" : "play.circle",
                                title: isPlaying ? "Stop" : "Play"
                            ) {
                                toggleSpeech()
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
            
            if message.isUser {
                // User Avatar
                Circle()
                    .fill(Gradients.accent)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .orange.opacity(0.3), radius: 5)
            }
        }
        .padding(.horizontal)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
    
    private func toggleSpeech() {
        if isPlaying {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isPlaying = false
        } else {
            let utterance = AVSpeechUtterance(string: message.content)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.5
            speechSynthesizer.speak(utterance)
            isPlaying = true
        }
    }
}

// MARK: -  Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        }
                }
                .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: -  Thinking Indicator
struct ThinkingIndicator: View {
    @State private var dots = [false, false, false]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Gradients.primary)
                    .frame(width: 10, height: 10)
                    .scaleEffect(dots[index] ? 1.3 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: dots[index]
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .stroke(Gradients.glass, lineWidth: 1)
                }
        }
        .onAppear {
            for index in 0..<3 {
                dots[index] = true
            }
        }
    }
}

// MARK: -  Input Field
struct InputField: View {
    @Binding var text: String
    @Binding var height: CGFloat
    @FocusState var isFocused: Bool
    let placeholder: String
    
    private let maxHeight: CGFloat = 250
    private let minHeight: CGFloat = 44
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Dynamic height measurement
            Text(text.isEmpty ? placeholder : text)
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
            
            // Actual text editor
            TextEditor(text: $text)
                .font(.system(size: 17))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .focused($isFocused)
                .frame(height: min(height, maxHeight))
                .scrollContentBackground(.hidden)
                .background {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(.ultraThickMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .stroke(
                                    isFocused ? Gradients.primary : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 2
                                )
                        }
                }
                
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(ViewHeightKey.self) { newHeight in
            DispatchQueue.main.async {
                height = max(minHeight, min(newHeight, maxHeight))
            }
        }
    }
}

// MARK: -  Navigation Bar
struct NavigationBar: View {
    let title: String
    let leftButton: AnyView?
    let rightButton: AnyView?
    
    init(title: String, leftButton: AnyView? = nil, rightButton: AnyView? = nil) {
        self.title = title
        self.leftButton = leftButton
        self.rightButton = rightButton
    }
    
    var body: some View {
        HStack {
            if let leftButton = leftButton {
                leftButton
            }
            
            Spacer()
            
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Gradients.primary)
            
            Spacer()
            
            if let rightButton = rightButton {
                rightButton
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        }
    }
}
