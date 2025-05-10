//
//  RealTimeChatView.swift
//  JumpAIAdvisor
//
//  Created by Kari Douglas on 5/10/25.
//

import SwiftUI
import AVFoundation

struct ModernRealTimeChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioManager = AudioManager()
    @State private var isListening = false
    @State private var isAISpeaking = false
    @State private var visualizerData = Array(repeating: 0.1, count: 60)
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()
            
            // Content
            VStack {
                // Close button with modern styling
                HStack {
                    Button(action: {
                        audioManager.stopListening()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .padding(.top, 8)
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                
                Spacer()
                
                // Center visualization
                ZStack {
                    if isAISpeaking {
                        ModernAudioVisualizer(data: $visualizerData)
                    } else {
                        ModernOrbitingLines(isActive: isListening)
                    }
                }
                .frame(height: 200)
                
                Spacer()
                
                // Status with animated appearance
                VStack(spacing: 16) {
                    StatusIndicator(text: statusText, isActive: isListening || isAISpeaking)
                    
                    if !audioManager.hasPermission {
                        AnimatedGradientButton("Enable Microphone", icon: "mic") {
                            audioManager.requestMicrophonePermission()
                        }
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            setupAudioManager()
        }
        .alert("Microphone Permission Required", isPresented: $audioManager.showPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please enable microphone access in Settings to use voice chat.")
        }
    }
    
    private var statusText: String {
        if !audioManager.hasPermission {
            return "Microphone access needed"
        } else if isListening {
            return "Listening..."
        } else if isAISpeaking {
            return "AI is speaking..."
        } else {
            return "Tap anywhere to speak"
        }
    }
    
    private func setupAudioManager() {
        audioManager.delegate = AudioDelegate(
            onStartListening: { isListening = true },
            onStopListening: { isListening = false },
            onStartSpeaking: { isAISpeaking = true },
            onStopSpeaking: { isAISpeaking = false }
        )
        audioManager.requestMicrophonePermission()
        
        // Start visualizer animation
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if isAISpeaking {
                visualizerData = (0..<60).map { _ in CGFloat.random(in: 0.1...1.0) }
            }
        }
    }
}

// MARK: - Animated Gradient Background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.purple.opacity(0.3),
                Color.blue.opacity(0.2),
                Color.black,
                Color.black,
                Color.blue.opacity(0.2),
                Color.purple.opacity(0.3)
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateGradient)
        .onAppear {
            animateGradient = true
        }
    }
}

// MARK: - Modern Orbiting Lines
struct ModernOrbitingLines: View {
    let isActive: Bool
    @State private var rotation = 0.0
    @State private var scale = 1.0
    @State private var opacity = 0.3
    
    var body: some View {
        ZStack {
            ForEach(0..<5) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.purple.opacity(0.8),
                                Color.pink.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: isActive ? 150 : 120,
                        height: isActive ? 4 : 3
                    )
                    .blur(radius: isActive ? 1 : 0)
                    .rotationEffect(.degrees(Double(index) * 36))
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(scale)
                    .opacity(isActive ? 0.8 : opacity)
                    .animation(
                        .easeInOut(duration: isActive ? 0.8 : 2.0)
                        .repeatForever(autoreverses: false),
                        value: rotation
                    )
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: scale
                    )
            }
        }
        .onAppear {
            rotation = 360
            scale = isActive ? 1.3 : 1.1
            opacity = isActive ? 0.8 : 0.3
        }
        .onChange(of: isActive) { newValue in
            scale = newValue ? 1.3 : 1.1
            opacity = newValue ? 0.8 : 0.3
        }
    }
}

// MARK: - Modern Audio Visualizer
struct ModernAudioVisualizer: View {
    @Binding var data: [CGFloat]
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 3) {
                ForEach(0..<data.count, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple,
                                    Color.blue,
                                    Color.cyan
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: geometry.size.width / CGFloat(data.count) - 3)
                        .frame(height: geometry.size.height * data[index])
                        .animation(
                            .interpolatingSpring(stiffness: 300, damping: 15),
                            value: data[index]
                        )
                        .blur(radius: 0.5)
                }
            }
            .frame(maxHeight: 120)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let text: String
    let isActive: Bool
    @State private var appeared = false
    
    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(
                isActive ? ModernGradients.primary : LinearGradient(colors: [.white.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .stroke(
                                isActive ? ModernGradients.primary : LinearGradient(colors: [.white.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 1
                            )
                    }
            }
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    appeared = true
                }
            }
            .shadow(color: isActive ? .purple.opacity(0.3) : .clear, radius: 10)
    }
}
