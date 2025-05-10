//
//  ContentView.swift
//  JumpAIAdvisor
//
//  Created by Kari Douglas on 5/10/25.
//


import SwiftUI

// Haptic feedback utility
struct HapticFeedback {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
    }
    
    static func tick() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    static func success() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }
    
    static func error() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.error)
    }
}

// Extension for keyboard handling
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Error handling
struct ErrorAlert: ViewModifier {
    @Binding var errorMessage: String?
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let message = errorMessage {
                    Text(message)
                }
            }
    }
}

extension View {
    func errorAlert(message: Binding<String?>) -> some View {
        modifier(ErrorAlert(errorMessage: message))
    }
}
