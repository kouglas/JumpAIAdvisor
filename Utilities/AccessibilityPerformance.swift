//
//  ContentView.swift
//  JumpAIAdvisor
//
//  Created by Kari Douglas on 5/10/25.
//


import SwiftUI

// MARK: - Accessibility Extensions
extension View {
    func accessibilityElement(type: AccessibilityTraits, label: String, hint: String? = nil) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(type)
    }
    
    func dynamicTypeSize(_ range: ClosedRange<DynamicTypeSize>) -> some View {
        self.dynamicTypeSize(range)
    }
}

// MARK: - Performance Optimizations
struct LazyContent<Content: View>: View {
    let content: () -> Content
    @State private var hasAppeared = false
    
    var body: some View {
        Group {
            if hasAppeared {
                content()
            } else {
                Color.clear
                    .onAppear {
                        hasAppeared = true
                    }
            }
        }
    }
}

// MARK: - Adaptive Layout
struct AdaptiveStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        if horizontalSizeClass == .regular && dynamicTypeSize < .xxLarge {
            HStack { content }
        } else {
            VStack { content }
        }
    }
}

// MARK: - Reduce Motion Support
struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation
    let reducedAnimation: Animation
    
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? reducedAnimation : animation)
    }
}

extension View {
    func adaptiveAnimation(_ animation: Animation, reduced: Animation = .easeInOut(duration: 0.2)) -> some View {
        modifier(ReducedMotionModifier(animation: animation, reducedAnimation: reduced))
    }
}

// MARK: - Optimized Image Loading
struct OptimizedAsyncImage: View {
    let url: URL?
    let placeholder: AnyView
    
    @State private var phase: AsyncImagePhase = .empty
    
    var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder
                    .onAppear {
                        loadImage()
                    }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            @unknown default:
                placeholder
            }
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.phase = .success(Image(uiImage: uiImage))
                }
            } else {
                DispatchQueue.main.async {
                    self.phase = .failure(NSError(domain: "", code: 0))
                }
            }
        }.resume()
    }
}

// MARK: - Memory Management
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    
    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - Haptic Feedback Enhancements
struct EnhancedHapticFeedback {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium, intensity: CGFloat = 1.0) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - Keyboard Avoidance
struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    withAnimation(.easeOut(duration: 0.25)) {
                        keyboardHeight = keyboardFrame.height
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = 0
                }
            }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptive())
    }
}

// MARK: - Theme Management
class ThemeManager: ObservableObject {
    @Published var currentTheme: ColorScheme = .dark
    @Published var accentColor: Color = .blue
    
    static let shared = ThemeManager()
    
    func toggleTheme() {
        currentTheme = currentTheme == .dark ? .light : .dark
    }
}

// MARK: - Error Handling with Recovery
struct ErrorRecoveryModifier: ViewModifier {
    @Binding var error: Error?
    let recovery: () -> Void
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("Retry") {
                    recovery()
                    error = nil
                }
                Button("Cancel", role: .cancel) {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
    }
}
