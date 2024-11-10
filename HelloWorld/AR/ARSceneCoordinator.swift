import ARKit
import Foundation
import SceneKit
import SwiftUI
import UIKit

class ARSceneCoordinator: NSObject, ARSCNViewDelegate {
    var arView: ARSCNView!
    var imageNodes: [SCNNode] = [] // Changed to array
    var gifNodes: [(node: SCNNode, displayLink: CADisplayLink)] = [] // Added for GIF tracking

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
    
    // Add new function to create and display GIF
    func createGIFNode(from url: URL, width: Float, height: Float, position: SCNVector3) {
        // Create a placeholder node first
        let plane = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        let node = SCNNode(geometry: plane)
        node.position = position
           
        plane.cornerRadius = 0.01
           
        let material = SCNMaterial()
        material.isDoubleSided = true
        plane.materials = [material]
           
        // Load GIF data asynchronously
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let source = CGImageSourceCreateWithData(data as CFData, nil)
            else {
                print("Failed to load GIF data")
                return
            }
               
            let frameCount = CGImageSourceGetCount(source)
            guard frameCount > 0 else { return }
               
            // Get frame durations
            var frameDurations: [TimeInterval] = []
            var totalDuration: TimeInterval = 0
               
            for i in 0..<frameCount {
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                   let duration = gifProperties[kCGImagePropertyGIFDelayTime as String] as? TimeInterval
                {
                    frameDurations.append(duration)
                    totalDuration += duration
                }
            }
               
            // Create array to store frame images
            var frames: [UIImage] = []
            for i in 0..<frameCount {
                if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                    frames.append(UIImage(cgImage: cgImage))
                }
            }
               
            // Set up display link for animation
            DispatchQueue.main.async {
                var frameIndex = 0
                var frameTime: TimeInterval = 0
                   
                let displayLink = CADisplayLink(target: self, selector: #selector(self.updateGIFFrame))
                displayLink.add(to: .main, forMode: .common)
                   
                // Store animation state in the display link
                let animationState = GIFAnimationState(
                    material: material,
                    frames: frames,
                    frameDurations: frameDurations,
                    currentFrame: frameIndex,
                    frameTime: frameTime
                )
                objc_setAssociatedObject(displayLink, &AssociatedKeys.animationState, animationState, .OBJC_ASSOCIATION_RETAIN)
                   
                // Add node to scene and track it
                self.arView.scene.rootNode.addChildNode(node)
                self.gifNodes.append((node: node, displayLink: displayLink))
                   
                // Start with first frame
                material.diffuse.contents = frames[0]
            }
        }.resume()
    }
        
    // Helper struct to store animation state
    private struct GIFAnimationState {
        let material: SCNMaterial
        let frames: [UIImage]
        let frameDurations: [TimeInterval]
        var currentFrame: Int
        var frameTime: TimeInterval
    }
        
    // Keys for associated objects
    private enum AssociatedKeys {
        static var animationState = "gifAnimationState"
    }
        
    @objc private func updateGIFFrame(displayLink: CADisplayLink) {
        guard let animationState = objc_getAssociatedObject(displayLink, &AssociatedKeys.animationState) as? GIFAnimationState else {
            return
        }
            
        var state = animationState
        state.frameTime += displayLink.duration
            
        // Check if it's time to advance to next frame
        if state.frameTime >= state.frameDurations[state.currentFrame] {
            state.frameTime = 0
            state.currentFrame = (state.currentFrame + 1) % state.frames.count
            state.material.diffuse.contents = state.frames[state.currentFrame]
        }
            
        // Update the stored state
        objc_setAssociatedObject(displayLink, &AssociatedKeys.animationState, state, .OBJC_ASSOCIATION_RETAIN)
    }
        
    // Clean up function for GIF nodes
    func removeAllGIFNodes() {
        for (node, displayLink) in gifNodes {
            displayLink.invalidate()
            node.removeFromParentNode()
        }
        gifNodes.removeAll()
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
