import SwiftUI
import AVFoundation
import Speech

struct RealTimeChatView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioManager = AudioManager()
    @State private var visualizationState: VisualizationState = .idle
    @State private var audioLevel: CGFloat = 0.0
    @State private var hasAppeared = false
    @State private var permissionRequested = false
    @State private var responseText: String = ""
    @State private var showResponse: Bool = false
    @State private var lastValidTranscription: String = ""
    @State private var speechPauseTimer: Timer?
    @State private var isSpeechPaused = false
    @State private var isProcessingResponse = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isSpeaking = false
    @State private var shouldUseAlternativeAudio = true  // Set to true to use alternative approach
    
    // For simulated audio vibration
    @State private var audioSimulationTimer: Timer?
    
    enum VisualizationState {
        case idle     // Original idle state
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
                    
                    // Display AI response text when available
                    if showResponse && !responseText.isEmpty {
                        Text(responseText)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.purple.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [.blue, .purple, .pink],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                ),
                                                lineWidth: 2
                                            )
                                    )
                            )
                            .shadow(color: .purple.opacity(0.5), radius: 10)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                            .transition(.opacity)
                            .animation(.easeInOut, value: showResponse)
                    }
                    
                    // Visualization content - KEEPING ORIGINAL ANIMATIONS
                    Group {
                        switch visualizationState {
                        case .idle:
                            IdleOrbitingBall()
                                .onTapGesture {
                                    startListeningIfPossible()
                                }
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
                        speechPauseTimer?.invalidate()
                        audioPlayer?.stop()
                        audioSimulationTimer?.invalidate()
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
            
            // Permission error overlay
            if audioManager.showPermissionAlert {
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        
                        Text("Microphone Access Required")
                            .font(.headline)
                        
                        Text("Please enable microphone access in Settings to use the voice chat feature.")
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Open Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue))
                        }
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                    .padding()
                    
                    Spacer()
                }
                .transition(.opacity)
                .animation(.easeInOut, value: audioManager.showPermissionAlert)
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
                    if isProcessingResponse {
                        Text("Processing: ✅")
                    }
                    if isSpeaking {
                        Text("Speaking: ✅")
                    } else {
                        Text("Speaking: ❌")
                    }
                    
                    // Add audio mode info
                    Text("Mode: \(shouldUseAlternativeAudio ? "Simulated" : "Speech")")
                        .foregroundColor(.yellow)
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding(.bottom, 150)
            }
        }
        .onAppear {
            setupAudioManager()
            configureAudioSession()
            
            // Play a silent sound to activate audio system
            playSilentSound()
            
            // Start audio level animation for speaking state
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                if visualizationState == .speaking {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        audioLevel = CGFloat.random(in: 0.2...1.0)
                    }
                }
            }
            
            // Auto-start listening with a slight delay to ensure proper initialization
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startListeningIfPossible()
            }
        }
        // Check for permission changes and attempt to start listening
        .onChange(of: audioManager.hasPermission) { newValue in
            if newValue {
                startListeningIfPossible()
            }
        }
        // Listen for transcription updates
        .onChange(of: audioManager.transcribedText) { newTranscription in
            if audioManager.transcribedText.isEmpty {
                return // Skip empty transcriptions
            }
            
            // Reset the timer every time we get new transcription
            resetSpeechPauseTimer()
            
            // Store the last valid transcription
            if !audioManager.transcribedText.isEmpty {
                lastValidTranscription = audioManager.transcribedText
            }
            
            // If the user stops speaking for a set period, finalize the transcription
            startSpeechPauseTimer()
        }
        .onChange(of: audioManager.isListening) { isListening in
            // If listening stops and we have a valid transcription
            if !isListening && !lastValidTranscription.isEmpty && !isSpeechPaused && !isProcessingResponse {
                // Stop the timer if it's running
                speechPauseTimer?.invalidate()
                
                // Process the last valid transcription if not already processing
                handleFinalTranscription(lastValidTranscription)
                
                // Clear the transcription only after processing
                lastValidTranscription = ""
            }
        }
        .onDisappear {
            // Clean up when view disappears
            speechPauseTimer?.invalidate()
            audioPlayer?.stop()
            audioSimulationTimer?.invalidate()
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
    
    // Play a silent sound to initialize audio system
    private func playSilentSound() {
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
            // Create an in-memory silent WAV file if needed
            let silentData = createSilentWavData()
            do {
                audioPlayer = try AVAudioPlayer(data: silentData)
                audioPlayer?.volume = 0.01
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch {
                print("❌ Failed to play silent sound: \(error)")
            }
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 0.01
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("❌ Failed to play silent sound: \(error)")
        }
    }
    
    // Create a simple silent WAV file in memory
    private func createSilentWavData() -> Data {
        // This is a minimal WAV file header + empty data for 0.1 second of silence
        var wavData = Data([
            0x52, 0x49, 0x46, 0x46, // "RIFF"
            0x24, 0x00, 0x00, 0x00, // Chunk size (36 + data size)
            0x57, 0x41, 0x56, 0x45, // "WAVE"
            0x66, 0x6D, 0x74, 0x20, // "fmt "
            0x10, 0x00, 0x00, 0x00, // Subchunk1 size (16 bytes)
            0x01, 0x00,             // Audio format (1 = PCM)
            0x01, 0x00,             // Num channels (1)
            0x44, 0xAC, 0x00, 0x00, // Sample rate (44100)
            0x44, 0xAC, 0x00, 0x00, // Byte rate (44100)
            0x01, 0x00,             // Block align (1)
            0x08, 0x00,             // Bits per sample (8)
            0x64, 0x61, 0x74, 0x61, // "data"
            0x00, 0x00, 0x00, 0x00, // Subchunk2 size (0 bytes of data)
        ])
        
        // Add a tiny bit of silent data (about 0.1 second)
        let silentSamples = [UInt8](repeating: 128, count: 4410) // 44100 * 0.1
        wavData.append(contentsOf: silentSamples)
        
        // Update the file size in the header
        let totalSize = UInt32(wavData.count - 8)
        var totalSizeBytes = withUnsafeBytes(of: totalSize.littleEndian) { Data($0) }
        wavData.replaceSubrange(4..<8, with: totalSizeBytes)
        
        // Update the data chunk size in the header
        let dataSize = UInt32(silentSamples.count)
        var dataSizeBytes = withUnsafeBytes(of: dataSize.littleEndian) { Data($0) }
        wavData.replaceSubrange(40..<44, with: dataSizeBytes)
        
        return wavData
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // First, deactivate the session
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            
            // Set the category with options
            try audioSession.setCategory(.playback,
                                      mode: .default,  // Use default mode instead of spokenAudio
                                      options: [.allowBluetooth, .allowBluetoothA2DP])
            
            // Override port to use speaker
            try audioSession.overrideOutputAudioPort(.speaker)
            
            // Activate the session with options
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Print current audio route
            if let currentRoute = audioSession.currentRoute.outputs.first {
                print("🔈 Current audio route: \(currentRoute.portType.rawValue)")
            }
            
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    private func setupAudioManager() {
        print("🎧 Setting up RealTimeChatView audio manager...")
        
        // Modified AudioDelegate to handle state changes
        audioManager.delegate = AudioDelegate(
            onStartListening: {
                withAnimation(.spring()) {
                    self.visualizationState = .listening
                    // Hide any previous response when starting to listen again
                    if self.visualizationState != .speaking {
                        self.showResponse = false
                    }
                }
                print("▶️ Started listening in RealTimeChatView")
            },
            onStopListening: {
                print("⏹️ Stopped listening in RealTimeChatView")
                // We'll handle this in the onChange(of: audioManager.isListening) handler
            },
            onStartSpeaking: {
                // We don't use this callback from AudioManager
                print("🔊 Original AudioManager speaking callback (unused)")
            },
            onStopSpeaking: {
                // We don't use this callback from AudioManager
                print("🔇 Original AudioManager speaking callback (unused)")
            }
        )
    }
    
    // Timer to detect pauses in speech
    private func startSpeechPauseTimer() {
        // Invalidate any existing timer
        speechPauseTimer?.invalidate()
        
        // Start a new timer
        speechPauseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            print("📣 Speech pause detected after 1.5 seconds")
            finalizeSpeechAfterPause()
        }
    }
    
    // Reset the speech timer
    private func resetSpeechPauseTimer() {
        speechPauseTimer?.invalidate()
        speechPauseTimer = nil
    }
    
    // Finalize speech after a pause
    private func finalizeSpeechAfterPause() {
        guard !lastValidTranscription.isEmpty && audioManager.isListening && !isProcessingResponse else { return }
        
        print("🎤 Finalizing speech after pause: \(lastValidTranscription)")
        isSpeechPaused = true
        isProcessingResponse = true
        
        // Store a local copy of the transcription
        let transcriptionToProcess = lastValidTranscription
        
        // Stop listening
        audioManager.stopListening()
        
        // Process the transcription
        handleFinalTranscription(transcriptionToProcess)
    }
    
    // Handle final transcription from the speech recognizer
    private func handleFinalTranscription(_ text: String) {
        print("✨ Processing final transcription: \(text)")
        
        // Skip empty transcriptions
        if text.isEmpty || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("⚠️ Skipping empty transcription")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isSpeechPaused = false
                self.isProcessingResponse = false
                self.startListeningIfPossible()
            }
            return
        }
        
        // Set flag to prevent duplicate processing
        isProcessingResponse = true
        
        HapticFeedback.impact()
        
        // Prepare audio for playback BEFORE the API call
        configureAudioSession()
        
        // Use the default OpenAI service
        let openAIService = OpenAIService()
        let userMessage = Message(content: text, isUser: true)
        
        openAIService.getChatCompletion(messages: [userMessage]) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Got AI response: \(response)")
                    
                    // Update UI with response
                    self.responseText = response
                    withAnimation {
                        self.showResponse = true
                        self.visualizationState = .speaking
                    }
                    
                    // Reconfigure audio and simulate the response
                    self.configureAudioSession()
                    
                    // Simulate speaking with a delay to ensure UI is updated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        // Use alternative audio approach that doesn't crash
                        self.simulateSpeaking(response)
                    }
                    
                case .failure(let error):
                    print("❌ AI error: \(error)")
                    
                    // Show error message
                    self.responseText = "Sorry, I encountered an error. Please try again."
                    withAnimation {
                        self.showResponse = true
                        self.visualizationState = .speaking
                    }
                    
                    // Simulate speaking error message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.simulateSpeaking("Sorry, I encountered an error. Please try again.")
                    }
                }
            }
        }
    }
    
    // Simulate speaking by playing tick sounds or silent sounds at word intervals
    private func simulateSpeaking(_ text: String) {
        print("🎵 Simulating speech for: \(text)")
        
        // Set state to speaking
        isSpeaking = true
        
        // Calculate a very rough duration based on text length and reading speed
        // Average reading speed is ~200 words per minute, so ~3.3 words per second
        let words = text.split(separator: " ")
        let wordCount = words.count
        let approximateDuration = Double(wordCount) / 3.3
        
        // Create a timer to simulate the speech duration
        let fixedDuration = max(2.0, min(approximateDuration, 15.0)) // Between 2-15 seconds
        
        print("🕒 Speaking simulation will run for \(String(format: "%.1f", fixedDuration)) seconds")
        
        // Play a short sound to ensure audio is working
        playTickSound()
        
        // Create a simulation timer to animate the speaking visualization
        audioSimulationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            // Animate the audioLevel for visualization
            self.audioLevel = CGFloat.random(in: 0.2...1.0)
            
            // Occasionally play a tick sound for feedback
            if Int.random(in: 0...20) == 0 {
                self.playTickSound()
            }
        }
        
        // Schedule the end of speaking
        DispatchQueue.main.asyncAfter(deadline: .now() + fixedDuration) {
            print("🔈 Finished simulated speaking")
            self.audioSimulationTimer?.invalidate()
            self.audioSimulationTimer = nil
            self.isSpeaking = false
            
            // Update UI state
            withAnimation(.spring()) {
                self.visualizationState = .idle
            }
            print("🔇 Stopped speaking in RealTimeChatView")
            
            // Give the user time to read the response before auto-restarting listening
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.isSpeechPaused = false
                self.isProcessingResponse = false
                self.startListeningIfPossible()
            }
        }
    }
    
    // Play a simple tick sound for feedback
    private func playTickSound() {
        // Provide haptic feedback instead of audio
        HapticFeedback.tick()
        
        // If you want to play an actual sound:
        // You would set up an AVAudioPlayer with a short tick.wav file
    }
    
    private func startListeningIfPossible() {
        // Only try to start listening if we're not already listening, speaking, or processing
        if !audioManager.isListening && visualizationState != .speaking && !isSpeechPaused && !isProcessingResponse && !isSpeaking {
            print("🎤 Attempting to start listening...")
            if audioManager.hasPermission {
                audioManager.startListening()
            } else if !permissionRequested {
                permissionRequested = true
                audioManager.requestMicrophonePermission()
            }
        } else {
            print("⚠️ Cannot start listening - currentState: \(visualizationState), isSpeechPaused: \(isSpeechPaused), isProcessing: \(isProcessingResponse), isSpeaking: \(isSpeaking)")
        }
    }
}

// ORIGINAL ANIMATIONS PRESERVED
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

