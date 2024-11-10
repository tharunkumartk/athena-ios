import ARKit
import Foundation
import SceneKit
import SwiftUI
import UIKit

struct ARSceneViewContainer: UIViewRepresentable {
    @ObservedObject var speechManager: SpeechRecognitionManager
    
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
        
        speechManager.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        guard speechManager.state == .finished,
              let currResponse = speechManager.currentResponse
        else {
            handleOtherStates(context)
            return
        }
        
        // Clean up existing content
        context.coordinator.removeAllImageNodes()
        context.coordinator.removeAllGIFNodes()
        context.coordinator.removeVideoNode()
        
        switch currResponse.contentType {
        case .slides:
            handleSlidesResponse(currResponse, context)
        case .chemistry:
            handleChemistryResponse(currResponse, context)
        case .math:
            handleMathResponse(currResponse, context)
        }
    }
    
    private func handleSlidesResponse(_ response: FinalAIResponse, _ context: Context) {
        if case .slides(let images) = response.media {
            let numberOfImages = images.count
            let maxDimension: Float = 0.4
            
            // Calculate positions for horizontal layout
            for (index, image) in images.enumerated() {
                let imageAspectRatio = Float(image.size.width / image.size.height)
                
                // Calculate width and height maintaining aspect ratio
                let imageWidth: Float
                let imageHeight: Float
                
                if imageAspectRatio > 1 {
                    imageWidth = maxDimension
                    imageHeight = maxDimension / imageAspectRatio
                } else {
                    imageHeight = maxDimension
                    imageWidth = maxDimension * imageAspectRatio
                }
                
                // Calculate spacing and positions
                let spacing: Float = 0.03
                let totalWidth = Float(numberOfImages) * imageWidth + Float(numberOfImages - 1) * spacing
                let startX = -totalWidth / 2 + imageWidth / 2
                
                // Calculate position for each image
                let xPosition = startX + Float(index) * (imageWidth + spacing)
                let position = SCNVector3(xPosition, 0.2, -0.5)
                
                // Create image node
                context.coordinator.createImageNode(
                    imgWidth: imageWidth,
                    imgHeight: imageHeight,
                    uiImage: image,
                    position: position
                )
            }
        }
    }
    
    private func handleChemistryResponse(_ response: FinalAIResponse, _ context: Context) {
        if case .gif(let gifUrl) = response.media {
            context.coordinator.createGIFNode(
                from: URL(string: gifUrl)!,
                width: 0.5,
                height: 0.5,
                position: SCNVector3(x: 0, y: 0, z: -1)
            )
        }
    }
    
    private func handleMathResponse(_ response: FinalAIResponse, _ context: Context) {
        if case .video(let videoUrl) = response.media {
            // Position the video slightly above eye level and at a comfortable viewing distance
            context.coordinator.createVideoNode(
                from: videoUrl,
                width: 0.6, // Slightly larger than images for better visibility
                height: 0.4, // Maintaining 3:2 aspect ratio
                position: SCNVector3(x: 0, y: 0.4, z: -1) // Centered, slightly above eye level, closer than GIFs
            )
        }
    }
    
    private func handleOtherStates(_ context: Context) {
        switch speechManager.state {
        case .processing:
            print("\nLOADING FROM API REQUEST !!!!! \n")
        case .recording, .listening:
            context.coordinator.updateSpeechVisualization(
                currentText: speechManager.currentText
            )
        default:
            break
        }
    }
    
    func makeCoordinator() -> ARSceneCoordinator {
        ARSceneCoordinator()
    }
}
