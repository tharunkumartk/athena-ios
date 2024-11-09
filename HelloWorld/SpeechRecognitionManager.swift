//
//  SpeechRecognitionManager.swift
//  HelloWorld
//
//  Created by Tharun Kumar on 11/9/24.
//

import ARKit
import SceneKit
import Speech
import SwiftUI
import UIKit

enum SpeechState {
    case inactive
    case recording
    case finished
}

class SpeechRecognitionManager: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var currentText = ""
    @Published var sentences: [String] = []
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 1.5
    private var lastProcessedText = ""
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
        
        print("🎤 Initializing speech recognition...")
        
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            print("🎤 Authorization status: \(status.rawValue)")
            guard status == .authorized else { return }
            DispatchQueue.main.async {
                self?.startListening()
            }
        }
    }
    
    private func startListening() {
        do {
            // Configure audio session
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
            
            print("🎤 Started listening")
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, _ in
                guard let self = self else { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    if text != self.lastProcessedText {
                        print("🗣️ Speech detected: \(text)")
                        DispatchQueue.main.async {
                            // If new speech is starting and we have existing text, move it to sentences
                            if !text.hasPrefix(self.currentText) && !self.currentText.isEmpty {
                                self.sentences.append(self.currentText)
                            }
                            self.currentText = text
                            self.lastProcessedText = text
                            self.resetSilenceTimer()
                        }
                    }
                }
            }
            
        } catch {
            print("❌ Failed to start speech recognition: \(error)")
        }
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // Only mark the sentence as complete, but don't clear currentText
            if !self.currentText.isEmpty {
                print("⏰ Command finished: \(self.currentText)")
                self.sentences.append(self.currentText)
            }
        }
    }
    
    deinit {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }
}
