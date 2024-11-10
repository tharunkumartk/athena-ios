import ARKit
import Foundation
import SceneKit
import SwiftUI
import UIKit

enum ARTextPanel {
    static let baseWidth = 50.0
    static let baseHeight = 20.0
    
    static func create(text: String, position: SCNVector3) -> SCNNode {
        // Create container node for both panel and text
        let containerNode = SCNNode()
        containerNode.position = position
        containerNode.scale = SCNVector3(0.02, 0.02, 0.02)
        
        // Create text
        let textGeometry = SCNText(string: text, extrusionDepth: 0)
        textGeometry.font = UIFont.systemFont(ofSize: 4)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        textGeometry.containerFrame = CGRect(x: 0, y: 0, width: baseWidth, height: baseHeight)
        textGeometry.isWrapped = true
        
        let textNode = SCNNode(geometry: textGeometry)
        
        // Create background panel slightly larger than text
        let panel = createBackgroundPanel(width: 1.1, height: 1.1)
        panel.position = SCNVector3(x: Float(baseWidth)/2, y: Float(baseHeight)/2, z: -0.1)
        
        // Add billboard constraint to container
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = .Y
        containerNode.constraints = [billboardConstraint]
        
        // Add panel and text to container
        containerNode.addChildNode(panel)
        containerNode.addChildNode(textNode)
        
        // Start with zero opacity
        containerNode.opacity = 0.0
        
        // Create and apply fade-in animation
        let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
        fadeInAnimation.fromValue = 0.0
        fadeInAnimation.toValue = 1.0
        fadeInAnimation.duration = 0.2
        fadeInAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        containerNode.addAnimation(fadeInAnimation, forKey: "fadeIn")
        containerNode.opacity = 1.0
        
        return containerNode
    }
    
    static func remove(_ node: SCNNode, completion: (() -> Void)? = nil) {
        node.removeFromParentNode()
    }

    private static func createTextMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.emission.contents = UIColor.white
        material.isDoubleSided = true
        material.lightingModel = .constant
        return material
    }

    private static func createBackgroundPanel(width: Float, height: Float) -> SCNNode {
        let cornerRadius = 5.0
        let panel = SCNPlane(width: CGFloat(width) * baseWidth, height: CGFloat(height) * baseHeight)
        panel.cornerRadius = cornerRadius
        
        let material = SCNMaterial()
        
        material.diffuse.contents = UIColor(white: 0.5, alpha: 0.4)
        material.isDoubleSided = true
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.2
        material.metalness.contents = 0.8
        
        let borderMaterial = SCNMaterial()
        borderMaterial.diffuse.contents = UIColor(white: 0.6, alpha: 0.4)
        
        let borderPanel = SCNPlane(width: CGFloat(width) * baseWidth + 1, height: CGFloat(height) * baseHeight + 1)
        borderPanel.cornerRadius = cornerRadius
        
        let borderNode = SCNNode(geometry: borderPanel)
        borderNode.geometry?.materials = [borderMaterial]
        borderNode.position = SCNVector3(0, 0, -0.01)
        
        panel.materials = [material]
        let mainNode = SCNNode(geometry: panel)
        
        let containerNode = SCNNode()
        containerNode.addChildNode(borderNode)
        containerNode.addChildNode(mainNode)
        
        return containerNode
    }
}
