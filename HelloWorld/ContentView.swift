import ARKit
import SceneKit
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var isImageVisible = false
    @State private var scale: Float = 1.0
    @State private var isStereoscopic = false
    @State private var sharedSession: ARSession = .init()
    @StateObject private var speechManager = SpeechRecognitionManager()
    
    var body: some View {
        ZStack {
            if isStereoscopic {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ARSceneViewContainer(
                            isImageVisible: $isImageVisible,
                            speechManager: speechManager,
                            scale: scale,
                            eye: .left,
                            sharedSession: sharedSession
                        )
                        .frame(width: geometry.size.width / 2)
                        
                        ARSceneViewContainer(
                            isImageVisible: $isImageVisible,
                            speechManager: speechManager,
                            scale: scale,
                            eye: .right,
                            sharedSession: sharedSession
                        )
                        .frame(width: geometry.size.width / 2)
                    }
                }
                .edgesIgnoringSafeArea(.all)
            } else {
                ARSceneViewContainer(
                    isImageVisible: $isImageVisible,
                    speechManager: speechManager,
                    scale: scale,
                    eye: .center,
                    sharedSession: nil
                )
                .edgesIgnoringSafeArea(.all)
            }
            
            VStack {
                Spacer()
                HStack {
                    Button(action: { isImageVisible.toggle() }) {
                        Text(isImageVisible ? "Hide Image" : "Show Image")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        if isImageVisible {
                            scale += 0.2
                        }
                    }) {
                        Text("Bigger")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        if isImageVisible, scale > 0.3 {
                            scale -= 0.2
                        }
                    }) {
                        Text("Smaller")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: { isStereoscopic.toggle() }) {
                        Text(isStereoscopic ? "Mono" : "Stereo")
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
            .onAppear {
                let configuration = ARWorldTrackingConfiguration()
                sharedSession.run(configuration)
            }
        }
    }
}

#Preview {
    ContentView()
}
