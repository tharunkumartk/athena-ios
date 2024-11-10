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

        // Add this line
        speechManager.arView = arView

        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if speechManager.state == .finished, let currResponse = speechManager.currentResponse {
            context.coordinator.removeAllImageNodes()

            let imageUrlStrings = currResponse.slides
            let numberOfImages = imageUrlStrings.count

            // Set a constant for the desired maximum dimension (in meters for SceneKit)
            let maxDimension: Float = 0.4 // SceneKit uses meters

            // Calculate positions for horizontal layout
            for (index, img) in imageUrlStrings.enumerated() {
                // Calculate aspect ratio of the image
                let imageAspectRatio = Float(img.size.width / img.size.height)

                // Calculate width and height maintaining aspect ratio
                let imageWidth: Float
                let imageHeight: Float

                if imageAspectRatio > 1 {
                    // Landscape image
                    imageWidth = maxDimension
                    imageHeight = maxDimension / imageAspectRatio
                } else {
                    // Portrait image
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
                    uiImage: img,
                    position: position
                )
            }
        } else if speechManager.state == .processing {
            print("\nLOADING FROM API REQUEST !!!!! \n")

        } else if speechManager.state == .recording {
            context.coordinator.updateSpeechVisualization(
                currentText: speechManager.currentText
            )
        } else if speechManager.state == .listening {
            context.coordinator.updateSpeechVisualization(
                currentText: speechManager.currentText
            )
        }
    }

    func makeCoordinator() -> ARSceneCoordinator {
        ARSceneCoordinator()
    }
}
