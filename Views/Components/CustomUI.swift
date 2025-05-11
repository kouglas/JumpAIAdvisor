import SwiftUI
import AVFoundation
import AVFAudio

struct ScrollAwareMessageBubble: View {
    let message: Message
    @State private var appeared = false
    @State private var isPlaying = false
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var displayedText = ""
    @State private var isTyping = false
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 12) {
                if !message.isUser {
                    // AI Avatar
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(0.8), .blue],
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
                                .symbolEffect(.pulse, value: isTyping)
                        }
                        .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)
                }
                
                if message.isUser {
                    Spacer(minLength: 50)
                }
                
                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                    if message.isThinking {
                        EnhancedThinkingIndicator()
                    } else {
                        // Message content with typing animation and markdown
                        RichMarkdownView(text: displayedText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background {
                                if message.isUser {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .blue.opacity(0.9)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                                } else {
                                    // Gradient that shifts with scroll
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.purple.opacity(0.15),
                                                            Color.blue.opacity(0.1),
                                                            Color.clear
                                                        ],
                                                        startPoint: UnitPoint(x: 0.5, y: scrollOffset * 0.001),
                                                        endPoint: UnitPoint(x: 0.5, y: 1 + scrollOffset * 0.001)
                                                    )
                                                )
                                        }
                                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                                }
                            }
                            .foregroundColor(message.isUser ? .white : .primary)
                        
                        // Action buttons
                        if !message.isUser && !message.content.isEmpty && !isTyping {
                            HStack(spacing: 16) {
                                ActionButton(icon: "doc.on.clipboard.fill", title: "Copy") {
                                    UIPasteboard.general.string = message.content
                                    HapticFeedback.success()
                                }
                                
                                ActionButton(
                                    icon: isPlaying ? "stop.fill" : "play.fill",
                                    title: isPlaying ? "Stop" : "Play"
                                ) {
                                    toggleSpeech()
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .slide))
                        }
                    }
                }
                
                if !message.isUser {
                    Spacer(minLength: 50)
                }
                
                if message.isUser {
                    // User Avatar
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.orange.opacity(0.8), .pink],
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
                        .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onChange(of: geometry.frame(in: .global).minY) { newValue in
                scrollOffset = newValue
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
            
            // Start typing animation for AI messages
            if !message.isUser && !message.isThinking && displayedText.isEmpty {
                startTypingAnimation()
            } else if message.isUser {
                displayedText = message.content
            }
        }
    }
    
    private func startTypingAnimation() {
        isTyping = true
        displayedText = ""
        var characterIndex = 0
        
        // Trigger haptic for first character
        HapticFeedback.tick()
        
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            if characterIndex < message.content.count {
                let index = message.content.index(message.content.startIndex, offsetBy: characterIndex)
                displayedText.append(message.content[index])
                characterIndex += 1
            } else {
                timer.invalidate()
                isTyping = false
                // Trigger haptic on completion
                HapticFeedback.tick()
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

// Rich Markdown View
struct RichMarkdownView: View {
    let text: String
    
    var body: some View {
        if let attributedString = try? AttributedString(markdown: text) {
            Text(attributedString)
                .textSelection(.enabled)
        } else {
            Text(text)
                .textSelection(.enabled)
        }
    }
}

// Enhanced Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
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
                HapticFeedback.impact(style: .light)
            }
        }) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.secondary, .secondary.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.2), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .offset(y: isPressed ? 1 : 0)
        }
    }
}

// Enhanced Thinking Indicator
struct EnhancedThinkingIndicator: View {
    @State private var dots = [false, false, false]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.8), .purple],
                            center: .center,
                            startRadius: 1,
                            endRadius: 5
                        )
                    )
                    .frame(width: 12, height: 12)
                    .scaleEffect(dots[index] ? 1.3 : 0.7)
                    .opacity(dots[index] ? 1 : 0.5)
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
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .onAppear {
            for index in 0..<3 {
                dots[index] = true
            }
        }
    }
}






//// MARK: -  Gradient Definitions
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

//// MARK: - Animated Gradient Border Button
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

//// MARK: - Glass Morphism Card
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

//// MARK: - Animated Send Button
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


//// MARK: -  Input Field
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

