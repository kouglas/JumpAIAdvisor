//
//  RealTimeChatView.swift
//  JumpAIAdvisor
//
//  Created by Kari Douglas on 5/10/25.
//

import SwiftUI
import AVFoundation

struct RealTimeChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioManager = AudioManager()
    @State private var visualizationState: VisualizationState = .idle
    @State private var audioLevel: CGFloat = 0.0
    @State private var hasAppeared = false
    
    enum VisualizationState {
        case idle
        case listening  // Shows orbiting lines
        case speaking   // Shows horizontal waveform
    }
    
    var body: some View {
        ZStack {
            // Dark background
            Color.black.ignoresSafeArea()
            
            // Center visualization based on state
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    
                    // Visualization content
                    Group {
                        switch visualizationState {
                        case .idle:
                            IdleOrbitingBall()
                        case .listening:
                            ListeningOrbitingBall()
                        case .speaking:
                            SpeakingWaveform(audioLevel: audioLevel)
                        }
                    }
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    
                    Spacer()
                    
                    // Status indicator
                    Text(statusText)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 100)
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Button(action: {
                        audioManager.stopListening()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .padding()
                    
                    Spacer()
                }
                
                Spacer()
            }
            
            // Debug information overlay
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    if audioManager.hasPermission {
                        Text("Permissions: ✅")
                    } else {
                        Text("Permissions: ❌")
                    }
                    if audioManager.isListening {
                        Text("Listening: ✅")
                    } else {
                        Text("Listening: ❌")
                    }
                    if !audioManager.transcribedText.isEmpty {
                        Text("Heard: \(audioManager.transcribedText)")
                    }
                    if let error = audioManager.errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                    }
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding(.bottom, 150)
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                setupAudioManager()
            }
        }
    }
    
    private var statusText: String {
        switch visualizationState {
        case .idle:
            return "Tap to speak"
        case .listening:
            return "Listening..."
        case .speaking:
            return "AI is speaking..."
        }
    }
    
    private func setupAudioManager() {
        print("🚀 Setting up audio manager...")
        
        audioManager.delegate = AudioDelegate(
            onStartListening: {
                withAnimation(.spring()) {
                    visualizationState = .listening
                }
            },
            onStopListening: {
                withAnimation(.spring()) {
                    if visualizationState == .listening {
                        visualizationState = .idle
                    }
                }
            },
            onStartSpeaking: {
                withAnimation(.spring()) {
                    visualizationState = .speaking
                }
            },
            onStopSpeaking: {
                withAnimation(.spring()) {
                    visualizationState = .idle
                }
            }
        )
        
        // Request permissions and start listening
        if audioManager.hasPermission {
            audioManager.startListening()
        } else {
            audioManager.requestMicrophonePermission()
        }
        
        // Start audio level animation for speaking state
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if visualizationState == .speaking {
                withAnimation(.easeInOut(duration: 0.1)) {
                    audioLevel = CGFloat.random(in: 0.2...1.0)
                }
            }
        }
    }
}

// Idle state: Slow orbiting lines
struct IdleOrbitingBall: View {
    @State private var rotation = 0.0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width/2, y: size.height/2)
                let time = timeline.date.timeIntervalSinceReferenceDate * 0.3 // Slow rotation
                
                // Draw 3-4 orbiting lines
                for i in 0..<3 {
                    let angle = Double(i) * 120 + time * 30
                    drawOrbitingLine(
                        context: context,
                        center: center,
                        radius: 100,
                        angle: angle,
                        thickness: 3,
                        alpha: 0.5
                    )
                }
            }
        }
    }
    
    private func drawOrbitingLine(context: GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double, thickness: CGFloat, alpha: Double) {
        let startAngle = angle * .pi / 180
        let endAngle = (angle + 120) * .pi / 180
        
        let startPoint = CGPoint(
            x: center.x + radius * cos(startAngle),
            y: center.y + radius * sin(startAngle) * 0.5 // Perspective
        )
        
        let endPoint = CGPoint(
            x: center.x + radius * cos(endAngle),
            y: center.y + radius * sin(endAngle) * 0.5 // Perspective
        )
        
        var path = Path()
        path.move(to: startPoint)
        
        // Create a curved line
        let control1 = CGPoint(
            x: center.x + radius * 1.2 * cos(startAngle + .pi/3),
            y: center.y + radius * 0.6 * sin(startAngle + .pi/3)
        )
        
        path.addQuadCurve(to: endPoint, control: control1)
        
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    .blue.opacity(alpha),
                    .purple.opacity(alpha),
                    .pink.opacity(alpha)
                ]),
                startPoint: startPoint,
                endPoint: endPoint
            ),
            lineWidth: thickness
        )
    }
}

// Listening state: Faster orbiting lines with pulsing
struct ListeningOrbitingBall: View {
    @State private var pulse = false
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width/2, y: size.height/2)
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                // Draw 4 fast-orbiting lines with pulsing effect
                for i in 0..<4 {
                    let angle = Double(i) * 90 + time * 60 // Faster rotation
                    let pulseScale = 1.0 + sin(time * 3) * 0.2 // Pulsing effect
                    
                    drawOrbitingLine(
                        context: context,
                        center: center,
                        radius: 100 * pulseScale,
                        angle: angle,
                        thickness: 4,
                        alpha: 0.8
                    )
                }
            }
        }
    }
    
    private func drawOrbitingLine(context: GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double, thickness: CGFloat, alpha: Double) {
        let startAngle = angle * .pi / 180
        let endAngle = (angle + 90) * .pi / 180
        
        let startPoint = CGPoint(
            x: center.x + radius * cos(startAngle),
            y: center.y + radius * sin(startAngle) * 0.5
        )
        
        let endPoint = CGPoint(
            x: center.x + radius * cos(endAngle),
            y: center.y + radius * sin(endAngle) * 0.5
        )
        
        var path = Path()
        path.move(to: startPoint)
        
        let control = CGPoint(
            x: center.x + radius * 1.3 * cos(startAngle + .pi/4),
            y: center.y + radius * 0.7 * sin(startAngle + .pi/4)
        )
        
        path.addQuadCurve(to: endPoint, control: control)
        
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    .blue.opacity(alpha),
                    .purple.opacity(alpha),
                    .pink.opacity(alpha)
                ]),
                startPoint: startPoint,
                endPoint: endPoint
            ),
            lineWidth: thickness
        )
        
        // Add glow effect
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    .blue.opacity(alpha * 0.3),
                    .purple.opacity(alpha * 0.3),
                    .pink.opacity(alpha * 0.3)
                ]),
                startPoint: startPoint,
                endPoint: endPoint
            ),
            lineWidth: thickness * 2
        )
    }
}

// Speaking state: Horizontal waveform equalizer
struct SpeakingWaveform: View {
    let audioLevel: CGFloat
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let width = size.width
                let height: CGFloat = 100
                let centerY = size.height / 2
                
                // Create waveform path
                let path = createWaveformPath(
                    width: width,
                    height: height,
                    centerY: centerY,
                    time: timeline.date.timeIntervalSinceReferenceDate,
                    audioLevel: audioLevel
                )
                
                // Draw main waveform
                drawMainWaveform(context: context, path: path, centerY: centerY, width: width)
                
                // Add glow effect
                drawGlowEffect(context: context, path: path, centerY: centerY, width: width)
                
                // Add edge anchors
                drawEdgeAnchors(context: context, centerY: centerY, width: width)
            }
        }
    }
    
    private func createWaveformPath(width: CGFloat, height: CGFloat, centerY: CGFloat, time: TimeInterval, audioLevel: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: centerY))
        
        for x in stride(from: 0, through: width, by: 2) {
            let waveY = calculateWaveY(
                x: x,
                width: width,
                height: height,
                centerY: centerY,
                time: time,
                audioLevel: audioLevel
            )
            path.addLine(to: CGPoint(x: x, y: waveY))
        }
        
        return path
    }
    
    private func calculateWaveY(x: CGFloat, width: CGFloat, height: CGFloat, centerY: CGFloat, time: TimeInterval, audioLevel: CGFloat) -> CGFloat {
        let progress = x / width
        
        // Combine multiple frequencies for complex waveform
        let wave1 = sin(progress * .pi * 8 + time * 3) * audioLevel
        let wave2 = sin(progress * .pi * 4 + time * 2) * audioLevel * 0.5
        let wave3 = sin(progress * .pi * 12 + time * 4) * audioLevel * 0.3
        
        let combinedWave = (wave1 + wave2 + wave3) * height * 0.3
        
        return centerY + combinedWave
    }
    
    private func drawMainWaveform(context: GraphicsContext, path: Path, centerY: CGFloat, width: CGFloat) {
        let gradient = Gradient(colors: [.blue, .purple, .pink, .orange])
        let startPoint = CGPoint(x: 0, y: centerY)
        let endPoint = CGPoint(x: width, y: centerY)
        
        context.stroke(
            path,
            with: .linearGradient(gradient, startPoint: startPoint, endPoint: endPoint),
            lineWidth: 3
        )
    }
    
    private func drawGlowEffect(context: GraphicsContext, path: Path, centerY: CGFloat, width: CGFloat) {
        let glowColors: [Color] = [
            .blue.opacity(0.3),
            .purple.opacity(0.3),
            .pink.opacity(0.3),
            .orange.opacity(0.3)
        ]
        
        let gradient = Gradient(colors: glowColors)
        let startPoint = CGPoint(x: 0, y: centerY)
        let endPoint = CGPoint(x: width, y: centerY)
        
        var glowContext = context
        glowContext.blendMode = .plusLighter
        
        glowContext.stroke(
            path,
            with: .linearGradient(gradient, startPoint: startPoint, endPoint: endPoint),
            lineWidth: 8
        )
    }
    
    private func drawEdgeAnchors(context: GraphicsContext, centerY: CGFloat, width: CGFloat) {
        let anchorRadius: CGFloat = 8
        
        // Left anchor
        let leftAnchorRect = CGRect(
            x: -anchorRadius,
            y: centerY - anchorRadius,
            width: anchorRadius * 2,
            height: anchorRadius * 2
        )
        
        context.fill(
            Circle().path(in: leftAnchorRect),
            with: .color(.blue)
        )
        
        // Right anchor
        let rightAnchorRect = CGRect(
            x: width - anchorRadius,
            y: centerY - anchorRadius,
            width: anchorRadius * 2,
            height: anchorRadius * 2
        )
        
        context.fill(
            Circle().path(in: rightAnchorRect),
            with: .color(.orange)
        )
    }
}

// Preference key for scroll detection
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
