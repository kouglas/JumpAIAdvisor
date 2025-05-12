import Foundation
import AVFoundation
import Speech

class AudioDelegate {
    let onStartListening: () -> Void
    let onStopListening: () -> Void
    let onStartSpeaking: () -> Void
    let onStopSpeaking: () -> Void
    
    init(onStartListening: @escaping () -> Void,
         onStopListening: @escaping () -> Void,
         onStartSpeaking: @escaping () -> Void,
         onStopSpeaking: @escaping () -> Void) {
        self.onStartListening = onStartListening
        self.onStopListening = onStopListening
        self.onStartSpeaking = onStartSpeaking
        self.onStopSpeaking = onStopSpeaking
    }
}

class AudioManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var hasPermission = false
    @Published var showPermissionAlert = false
    @Published var errorMessage: String?
    @Published var transcribedText: String = ""
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    var delegate: AudioDelegate?
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
        print("🚀 Setting up audio manager...")
        requestMicrophonePermission()
    }
    
    func requestMicrophonePermission() {
        print("🎤 Requesting microphone permissions...")
        
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                print("🎤 Speech recognition auth status: \(authStatus)")
                switch authStatus {
                case .authorized:
                    self?.checkMicrophonePermission()
                case .denied, .restricted:
                    self?.hasPermission = false
                    self?.showPermissionAlert = true
                case .notDetermined:
                    self?.hasPermission = false
                @unknown default:
                    self?.hasPermission = false
                }
            }
        }
    }
    
    private func checkMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                print("🎤 Microphone permission: \(granted)")
                self?.hasPermission = granted
                if granted {
                    self?.setupAudioSession()
                } else {
                    self?.showPermissionAlert = true
                }
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Changed from .record to .playAndRecord to support defaultToSpeaker
            try audioSession.setCategory(.playAndRecord,
                                        mode: .spokenAudio,
                                        options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session configured successfully")
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            print("❌ Audio session error: \(error)")
        }
    }
    
    // Configure audio session specifically for recording
    private func configureAudioSessionForRecording() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playAndRecord with defaultToSpeaker for consistent behavior
            try audioSession.setCategory(.playAndRecord,
                                        mode: .spokenAudio,
                                        options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to configure audio session for recording: \(error)")
            errorMessage = "Failed to configure recording: \(error.localizedDescription)"
        }
    }
    
    // Configure audio session specifically for playback
    private func configureAudioSessionForPlayback() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // For playback only, but stay consistent with playAndRecord category
            try audioSession.setCategory(.playAndRecord,
                                        mode: .spokenAudio,
                                        options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to configure audio session for playback: \(error)")
            errorMessage = "Failed to configure playback: \(error.localizedDescription)"
        }
    }
    
    func startListening() {
        print("🎤 Starting to listen...")
        guard hasPermission else {
            print("❌ No permission to start listening")
            requestMicrophonePermission()
            return
        }
        
        guard !isListening else {
            print("⚠️ Already listening")
            return
        }
        
        do {
            // Clean up any existing session
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
            }
            
            // Configure audio session for recording
            configureAudioSessionForRecording()
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else {
                throw NSError(domain: "AudioManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
            }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isListening = true
            delegate?.onStartListening()
            print("✅ Listening started successfully")
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    print("🗣️ Heard: \(transcription)")
                    self?.transcribedText = transcription
                    
                    if result.isFinal {
                        print("🏁 Recognition final")
                        self?.stopListening()
                        self?.processTranscription(transcription)
                    }
                }
                
                if let error = error {
                    print("❌ Recognition error: \(error)")
                    self?.stopListening()
                    self?.errorMessage = "Recognition error: \(error.localizedDescription)"
                }
            }
        } catch {
            print("❌ Failed to start listening: \(error)")
            stopListening()
            errorMessage = "Failed to start listening: \(error.localizedDescription)"
        }
    }
    
    func stopListening() {
        print("🛑 Stopping listening...")
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        
        delegate?.onStopListening()
        print("✅ Listening stopped")
    }
    
    private func processTranscription(_ text: String) {
        print("🔄 Processing transcription: \(text)")
        HapticFeedback.impact()
        
        let openAIService = OpenAIService()
        let userMessage = Message(content: text, isUser: true)
        
        openAIService.getChatCompletion(messages: [userMessage]) { [weak self] result in
            switch result {
            case .success(let response):
                print("✅ Got AI response: \(response)")
                self?.speakResponse(response)
            case .failure(let error):
                print("❌ AI error: \(error)")
                self?.errorMessage = error.localizedDescription
                self?.speakResponse("I'm sorry, I encountered an error. Please try again.")
            }
        }
    }
    
    private func speakResponse(_ text: String) {
        print("🔊 Speaking response: \(text)")
        
        // Configure audio session for playback before speaking
        configureAudioSessionForPlayback()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.9
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        delegate?.onStartSpeaking()
        speechSynthesizer.speak(utterance)
    }
}

extension AudioManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        delegate?.onStopSpeaking()
        
        // Resume listening after AI finishes speaking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startListening()
        }
    }
}
