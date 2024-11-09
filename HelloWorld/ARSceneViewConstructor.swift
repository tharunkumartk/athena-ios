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
                createImageNode(in: uiView, context: context)
            }
            context.coordinator.imageNode?.scale = SCNVector3(scale, scale, scale)
        } else {
            context.coordinator.imageNode?.removeFromParentNode()
            context.coordinator.imageNode = nil
        }
        
        // Update speech visualization
        context.coordinator.updateSpeechVisualization(
            currentText: speechManager.currentText,
            completedSentences: speechManager.sentences
        )
    }
    
    private func createImageNode(in arView: ARSCNView, context: Context) {
        let plane = SCNPlane(width: 0.3, height: 0.4)
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, 0, -0.5)
        
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
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var arView: ARSCNView!
        var imageNode: SCNNode?
        var currentTextNode: SCNNode?
        var completedTextNodes: [SCNNode] = []
        var eye: Eye = .center
        let ipd: Float = 0.063
        
        func updateSpeechVisualization(currentText: String, completedSentences: [String]) {
            DispatchQueue.main.async {
                print("📝 Updating visualization - Current text: \(currentText)")
                
                self.currentTextNode?.removeFromParentNode()
                self.completedTextNodes.forEach { $0.removeFromParentNode() }
                self.completedTextNodes.removeAll()
                
                // Create node for current text if not empty
                if !currentText.isEmpty {
                    let node = self.createPanelWithText(
                        text: currentText,
                        textColor: .white,
                        position: SCNVector3(x: 0, y: 0.2, z: -1),
                        scale: 0.09 // Increased scale
                    )
                    self.arView.scene.rootNode.addChildNode(node)
                    self.currentTextNode = node
                }
            }
        }
        
        private func createPanelWithText(text: String, textColor: UIColor, position: SCNVector3, scale: Float) -> SCNNode {
            // Create container node
            let containerNode = SCNNode()
            
            // Create text geometry with refined settings
            let textGeometry = SCNText(string: text, extrusionDepth: 0)
            textGeometry.font = UIFont.systemFont(ofSize: 1, weight: .regular)
            textGeometry.flatness = 0.005
            textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue
            
            // Enhanced text material for better visibility
            let textMaterial = SCNMaterial()
            textMaterial.diffuse.contents = UIColor.white
            textMaterial.emission.contents = UIColor.white
            textMaterial.isDoubleSided = true
            textMaterial.lightingModel = .constant
            textGeometry.materials = [textMaterial]
            
            // Create text node
            let textNode = SCNNode(geometry: textGeometry)
            
            // Calculate bounds for centering
            let (min, max) = textGeometry.boundingBox
            let textWidth = max.x - min.x
            let textHeight = max.y - min.y
            
            // Center the text node at origin
            textNode.position = SCNVector3(
                -textWidth/2,
                -textHeight/2,
                0
            )
            
            // Create background panel
            let panelWidth = textWidth + 0.4 // Reduced padding
            let panelHeight = textHeight + 0.2 // Reduced padding
            let panel = SCNPlane(width: CGFloat(panelWidth), height: CGFloat(panelHeight))
            
            // Create glass morphism background
            let size = CGSize(width: 800, height: 400)
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            let context = UIGraphicsGetCurrentContext()!
            let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            let cornerRadius: CGFloat = 40
            
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            context.addPath(path.cgPath)
            
            // Create gradient
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradientColors = [
                UIColor(white: 0, alpha: 0.7).cgColor,
                UIColor(white: 0, alpha: 0.5).cgColor
            ] as CFArray
            
            let locations: [CGFloat] = [0.0, 1.0]
            let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations)!
            
            context.clip()
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: size.width, y: size.height),
                                       options: [])
            
            // Add border glow
            context.setStrokeColor(UIColor(white: 1, alpha: 0.2).cgColor)
            context.setLineWidth(2)
            path.stroke()
            
            let backgroundImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            // Configure panel material
            let panelMaterial = SCNMaterial()
            panelMaterial.diffuse.contents = backgroundImage
            panelMaterial.isDoubleSided = true
            panelMaterial.lightingModel = .constant
            panel.materials = [panelMaterial]
            
            // Create panel node and position it slightly behind text
            let panelNode = SCNNode(geometry: panel)
            panelNode.position = SCNVector3(0, 1, -0.001) // Very slight offset behind text
            
            // Assemble final node hierarchy
            containerNode.addChildNode(panelNode)
            containerNode.addChildNode(textNode)
            
            // Set final position and scale
            containerNode.position = position
            containerNode.scale = SCNVector3(scale, scale, scale)
            
            // Add billboard constraint
            let billboardConstraint = SCNBillboardConstraint()
            billboardConstraint.freeAxes = .all
            containerNode.constraints = [billboardConstraint]
            
            return containerNode
        }
        
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let pointOfView = arView.pointOfView else { return }
            
            if eye != .center {
                let cameraTransform = pointOfView.simdTransform
                let eyeOffset = simd_float4x4(translation: SIMD3<Float>(eye == .left ? -ipd/2 : ipd/2, 0, 0))
                let eyeTransform = simd_mul(cameraTransform, eyeOffset)
                pointOfView.simdTransform = eyeTransform
            }
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
}®
