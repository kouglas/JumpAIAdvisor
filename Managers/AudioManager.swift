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
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    var delegate: AudioDelegate?
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    func requestMicrophonePermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
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
                self?.hasPermission = granted
                if granted {
                    self?.setupAudioSession()
                    self?.startListening()
                } else {
                    self?.showPermissionAlert = true
                }
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    func startListening() {
        guard hasPermission, !isListening else { return }
        
        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = recognitionRequest else {
                throw NSError(domain: "AudioManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isListening = true
            delegate?.onStartListening()
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self?.stopListening()
                        self?.processTranscription(transcription)
                    }
                }
                
                if let error = error {
                    self?.stopListening()
                    self?.errorMessage = "Recognition error: \(error.localizedDescription)"
                }
            }
        } catch {
            stopListening()
            errorMessage = "Failed to start listening: \(error.localizedDescription)"
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        
        delegate?.onStopListening()
    }
    
    private func processTranscription(_ text: String) {
        // Process with OpenAI
        HapticFeedback.impact()
        
        let openAIService = OpenAIService()
        let userMessage = Message(content: text, isUser: true)
        
        openAIService.getChatCompletion(messages: [userMessage]) { [weak self] result in
            switch result {
            case .success(let response):
                self?.speakResponse(response)
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
                self?.speakResponse("I'm sorry, I encountered an error. Please try again.")
            }
        }
    }
    
    private func speakResponse(_ text: String) {
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