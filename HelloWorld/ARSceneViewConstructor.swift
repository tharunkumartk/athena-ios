//
//  ARSceneViewConstructor.swift
//  HelloWorld
//
//  Created by Tharun Kumar on 11/9/24.
//

import ARKit
import SceneKit
import SwiftUI
import UIKit

enum Eye {
    case left, right, center
}

struct ARSceneViewContainer: UIViewRepresentable {
    @Binding var isImageVisible: Bool
    var scale: Float
    var eye: Eye

    var sharedSession: ARSession?

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.delegate = context.coordinator
        arView.scene = SCNScene()

        // Use shared session if provided, otherwise create new one
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
        // Handle model visibility and scale
        if isImageVisible {
            if context.coordinator.imageNode == nil {
                createImageNode(in: uiView, context: context)
            }
            context.coordinator.imageNode?.scale = SCNVector3(scale, scale, scale)
        } else {
            context.coordinator.imageNode?.removeFromParentNode()
            context.coordinator.imageNode = nil
        }
    }

    private func createImageNode(in arView: ARSCNView, context: Context) {
        // Create plane geometry
        let plane = SCNPlane(width: 0.3, height: 0.4)

        // Create node
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, 0, -0.5)

        // Load and apply texture
        let imageUrl = URL(string: "https://tharunkumar.xyz/static/1d669eb50394d8904683073b5be62826/fe92a/me.avif")!

        URLSession.shared.dataTask(with: imageUrl) { data, _, _ in
            guard let data = data, let uiImage = UIImage(data: data) else {
                print("Failed to load image from URL")
                return
            }

            DispatchQueue.main.async {
                plane.firstMaterial?.diffuse.contents = uiImage
                plane.firstMaterial?.isDoubleSided = true
            }
        }.resume()

        arView.scene.rootNode.addChildNode(node)
        context.coordinator.imageNode = node
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        var arView: ARSCNView!
        var imageNode: SCNNode?
        var eye: Eye = .center
        let ipd: Float = 0.063 // Average interpupillary distance in meters

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let pointOfView = arView.pointOfView else { return }

            // Only apply eye offset in stereoscopic mode
            if eye != .center {
                let cameraTransform = pointOfView.simdTransform

                // Calculate eye offset based on interpupillary distance
                let eyeOffset: simd_float4x4
                switch eye {
                case .left:
                    eyeOffset = simd_float4x4(translation: SIMD3<Float>(-ipd / 2, 0, 0))
                case .right:
                    eyeOffset = simd_float4x4(translation: SIMD3<Float>(ipd / 2, 0, 0))
                case .center:
                    eyeOffset = matrix_identity_float4x4
                }

                // Apply eye offset
                let eyeTransform = simd_mul(cameraTransform, eyeOffset)
                pointOfView.simdTransform = eyeTransform
            }
        }

        // Add method to handle scene setup
        func setupScene() {
            guard let arView = arView else { return }

            // Ensure proper rendering settings
            arView.rendersContinuously = true
            arView.preferredFramesPerSecond = 60

            // Optional: Add ambient light to ensure visibility
            let ambientLight = SCNLight()
            ambientLight.type = .ambient
            ambientLight.intensity = 1000
            let ambientLightNode = SCNNode()
            ambientLightNode.light = ambientLight
            arView.scene.rootNode.addChildNode(ambientLightNode)
        }
    }
}

// Helper extension for translation matrix
extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self.init(simd_float4(1, 0, 0, 0),
                  simd_float4(0, 1, 0, 0),
                  simd_float4(0, 0, 1, 0),
                  simd_float4(translation.x, translation.y, translation.z, 1))
    }
}
