//
//  ARSceneViewConstructor.swift
//  HelloWorld
//
//  Created by Tharun Kumar on 11/9/24.
//

// ARSceneViewContainer.swift
import ARKit
import Foundation
import SceneKit
import SwiftUI
import UIKit

struct ARSceneViewContainer: UIViewRepresentable {
    @Binding var isImageVisible: Bool
    @ObservedObject var speechManager: SpeechRecognitionManager
    var scale: Float
    var eye: Eye
    var sharedSession: ARSession?
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.delegate = context.coordinator
        arView.scene = SCNScene()
        
        if let shared = sharedSession {
            arView.session = shared
        } else {
            let configuration = ARWorldTrackingConfiguration()
            arView.session.run(configuration)
        }
        
        context.coordinator.arView = arView
        context.coordinator.eye = eye
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if isImageVisible {
            if context.coordinator.imageNode == nil {
                context.coordinator.createImageNode()
            }
            context.coordinator.imageNode?.scale = SCNVector3(scale, scale, scale)
        } else {
            context.coordinator.imageNode?.removeFromParentNode()
            context.coordinator.imageNode = nil
        }
        
        context.coordinator.updateSpeechVisualization(
            currentText: speechManager.currentText,
            completedSentences: speechManager.sentences
        )
    }
    
    func makeCoordinator() -> ARSceneCoordinator {
        ARSceneCoordinator()
    }
}
