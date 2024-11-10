import ARKit
import AVFoundation
import SceneKit
import Speech
import SwiftUI
import UIKit

enum SpeechState {
    case listening
    case recording
    case processing
    case finished
}

class SpeechRecognitionManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var currentText = ""
    @Published var state: SpeechState = .listening
    @Published var currentResponse: FinalAIResponse?
    
    @Published var audioPlayerViewModel: AudioPlayerViewModel = .init()
    @Published var urlHandler: ((String) async -> Void)?

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.5
    private var lastProcessedText = ""
    private let wakeWord = "athena"
    private let stopPhrase = "thanks athena"
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self

        print("🎤 Initializing speech recognition...")
               
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            print("🎤 Authorization status: \(status.rawValue)")
            guard status == .authorized else { return }
            DispatchQueue.main.async {
                self?.startListeningForWakeWord()
            }
        }
    }
    
    private func nullifySpeechComponents() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    private func processSpeechCommand() {
        Task {
            do {
                state = .processing
                    
                // Nullify all speech components and configure audio session for playback
                nullifySpeechComponents()
                    
                // Configure audio session for playback
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
                    
                if let urlHandler = urlHandler {
                    await urlHandler("https://tmpfiles.org/dl/15460248/letmethinkaboutit.mp3")
                } else {
                    print("Not initialized")
                }
                    
                let response = try await NetworkManager.shared.sendPrompt(currentText)
                    
                await MainActor.run {
                    self.currentResponse = response
                    self.state = .finished
                    
                    Task {
                        do {
                            if let handler = self.urlHandler, let audioURL = self.currentResponse?.audioURL {
                                nullifySpeechComponents()

                                try? await Task.sleep(nanoseconds: 500000000) // 0.5 sec delay

                                // Configure audio session for playback
                                let audioSession = AVAudioSession.sharedInstance()
                                try audioSession.setCategory(.playback, mode: .default)
                                try audioSession.setActive(true)
                                await handler(audioURL)
                                
                                try? await Task.sleep(nanoseconds: 8000000000) // 8 sec delay
                                
                                // After audio playback, start listening for wake word again
                                startListeningForWakeWord()
                            } else {
                                print("Could not find the url or handler")
                                startListeningForWakeWord() // Start listening even if audio fails
                            }
                        } catch {
                            print("Error in audio playback: \(error)")
                            startListeningForWakeWord() // Start listening if there's an error
                        }
                    }
                }
                    
            } catch {
                print("❌ API request failed: \(error)")
                await MainActor.run {
                    self.state = .finished
                    self.startListeningForWakeWord() // Start listening if API request fails
                }
            }
        }
    }
        
    private func restartSpeechRecognition() {
        do {
            // Reconfigure audio session for recording
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
                
            currentText = ""
                
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
                
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("❌ Failed to restart speech recognition: \(error)")
        }
    }
    
    func startListeningForWakeWord() {
        state = .listening
        currentText = ""
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            print("🎤 Started listening for wake word")
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, _ in
                guard let self = self else { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString.lowercased()
                    
                    DispatchQueue.main.async {
                        switch self.state {
                        case .listening:
                            if text.contains(self.wakeWord) {
                                print("🎯 Wake word detected!")
                                self.transitionToRecording()
                            }
                            
                        case .recording:
                            if text.contains(self.stopPhrase) {
                                print("👋 Stop phrase detected!")
                                self.reset() // Call reset instead of just changing state
                            } else {
                                if text != self.lastProcessedText {
                                    print("🗣️ Speech detected: \(text)")
                                    self.currentText = text
                                    self.lastProcessedText = text
                                    self.resetSilenceTimer()
                                }
                            }
                            
                        case .finished:
                            if text.contains(self.wakeWord) {
                                print("🎯 Wake word detected in finished state!")
                                self.transitionToRecording()
                            }
                            
                        case .processing:
                            break
                        }
                    }
                }
            }
            
        } catch {
            print("❌ Failed to start speech recognition: \(error)")
        }
    }
    
    private func transitionToRecording() {
        state = .recording
        currentResponse = nil
        currentText = ""
        lastProcessedText = ""
        resetSilenceTimer()
        print("🎤 Transitioned to recording mode")
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.currentText.isEmpty && self.state == .recording {
                print("⏰ Command finished: \(self.currentText)")
                self.processSpeechCommand()
            }
        }
    }
    
    func reset() {
        nullifySpeechComponents()
        startListeningForWakeWord()
    }
    
    private func stopCurrentRecognition() {
        nullifySpeechComponents()
    }
    
    deinit {
        stopCurrentRecognition()
    }
}
