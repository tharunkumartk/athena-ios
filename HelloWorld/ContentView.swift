import ARKit
import AVFoundation
import SceneKit
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var isStereoscopic = false
    @State private var sharedSession: ARSession = .init()
    @StateObject private var speechManager = SpeechRecognitionManager()

    @StateObject var audioPlayerViewModel = AudioPlayerViewModel()

    var body: some View {
        ZStack {
            if isStereoscopic {
                GeometryReader { geometry in
                    HStack {
                        ARSceneViewContainer(
                            speechManager: speechManager,
                            eye: .left,
                            sharedSession: sharedSession
                        )
                        .frame(width: geometry.size.width / 2)

                        ARSceneViewContainer(
                            speechManager: speechManager,
                            eye: .right,
                            sharedSession: sharedSession
                        )
                        .frame(width: geometry.size.width / 2)
                    }
                }
                .edgesIgnoringSafeArea(.all)
            } else {
                ARSceneViewContainer(
                    speechManager: speechManager,
                    eye: .center,
                    sharedSession: nil
                )
                .edgesIgnoringSafeArea(.all)
            }

            VStack {
                Spacer()
                HStack {
                    Button(action: { isStereoscopic.toggle() }) {
                        Text(isStereoscopic ? "Mono" : "Stereo")
                            .padding(3)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            .onAppear {
                let configuration = ARWorldTrackingConfiguration()
                sharedSession.run(configuration)
                speechManager.urlHandler = { audioUrl in
                    await audioPlayerViewModel.loadAudio(from: audioUrl)
                    audioPlayerViewModel.play()
                }
            }
        }
    }
}

class AudioPlayerViewModel: ObservableObject {
    private var audioPlayer: AVAudioPlayer?

    func loadAudio(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        do {
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try await audioSession.setCategory(.playback, mode: .default)
            try await audioSession.setActive(true)

            let data = try await URLSession.shared.data(from: url).0
            try await MainActor.run {
                self.audioPlayer = try AVAudioPlayer(data: data)
                self.audioPlayer?.prepareToPlay()
            }
        } catch {
            print("Failed to load audio data: \(error)")
        }
    }

    func play() {
        guard let player = audioPlayer else {
            print("No audio player available")
            return
        }

        let success = player.play()
        print("Playing audio: \(success)")
    }
}
