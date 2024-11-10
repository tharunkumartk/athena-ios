import ARKit
import Foundation
import SceneKit
import SwiftUI
import UIKit

class ARSceneCoordinator: NSObject, ARSCNViewDelegate {
    var arView: ARSCNView!
    var imageNodes: [SCNNode] = [] // Changed to array

    var loadingNode: SCNNode?
    var currentTextNode: SCNNode?
    var eye: Eye = .center
    let ipd: Float = 0.063
    
    func updateSpeechVisualization(currentText: String) {
        DispatchQueue.main.async {
            // If there's an existing text node, fade it out first
            if let existingNode = self.currentTextNode {
                ARTextPanel.remove(existingNode) {
                    self.currentTextNode = nil
                }
            }
            
            // Create new text node if there's text to display
            if !currentText.isEmpty {
                let node = ARTextPanel.create(
                    text: currentText,
                    position: SCNVector3(x: -0.5, y: -0.5, z: -2)
                )
                self.arView.scene.rootNode.addChildNode(node)
                self.currentTextNode = node
            }
        }
    }
    
    func removeAllImageNodes(completion: (() -> Void)? = nil) {
        let group = DispatchGroup()
            
        for node in imageNodes {
            group.enter()
                
            // Create fade out animation
            let fadeAnimation = CABasicAnimation(keyPath: "opacity")
            fadeAnimation.fromValue = 1.0
            fadeAnimation.toValue = 0.0
            fadeAnimation.duration = 0.2
            fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                
            // Set up completion handler
            fadeAnimation.delegate = AnimationDelegate {
                node.removeFromParentNode()
                group.leave()
            }
                
            // Apply the fade out animation
            node.addAnimation(fadeAnimation, forKey: "fadeOut")
            node.opacity = 0.0
        }
            
        group.notify(queue: .main) {
            self.imageNodes.removeAll()
            completion?()
        }
    }
    
    func createImageNode(imgWidth: Float, imgHeight: Float, uiImage: UIImage, position: SCNVector3 = SCNVector3(0, 0, -0.5), rotationRadians: Float = 0) {
        createNewImageNode(imageWidth: imgWidth, imageHeight: imgHeight, uiImage: uiImage, position: position, rotationRadians: rotationRadians)
    }
           
    private func createNewImageNode(imageWidth: Float, imageHeight: Float, uiImage: UIImage, position: SCNVector3, rotationRadians: Float) {
        let plane = SCNPlane(width: CGFloat(imageWidth), height: CGFloat(imageHeight))
        let node = SCNNode(geometry: plane)
           
        // Calculate the rotation in radians and apply it around the Y-axis
        node.eulerAngles.y = rotationRadians
           
        // Adjust position based on rotation to maintain relative placement
        let distance = sqrt(position.x * position.x + position.z * position.z)
        let baseAngle = atan2(position.x, position.z)
        let newAngle = baseAngle + rotationRadians
           
        let adjustedPosition = SCNVector3(
            x: distance * sin(newAngle),
            y: position.y,
            z: distance * cos(newAngle)
        )
        node.position = adjustedPosition
           
        plane.cornerRadius = 0.01
               
//        // Add billboard constraint to make node always face the camera
//        let billboardConstraint = SCNBillboardConstraint()
//        billboardConstraint.freeAxes = .Y // Only rotate around Y axis to maintain upright position
//        node.constraints = [billboardConstraint]
                   
        // Start with fully transparent materials
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.clear
        material.isDoubleSided = true
        plane.materials = [material]
               
        DispatchQueue.main.async {
            // Create animation for opacity
            let fadeAnimation = CABasicAnimation(keyPath: "opacity")
            fadeAnimation.fromValue = 0.0
            fadeAnimation.toValue = 1.0
            fadeAnimation.duration = 0.2
            fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                           
            // Set the final image and animate
            material.diffuse.contents = uiImage
            node.opacity = 0.0
                           
            self.arView.scene.rootNode.addChildNode(node)
            self.imageNodes.append(node)
                           
            // Apply the fade animation
            node.addAnimation(fadeAnimation, forKey: "fadeIn")
            node.opacity = 1.0
        }
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
