//
//  ARTextPanel.swift
//  HelloWorld
//
//  Created by Tharun Kumar on 11/9/24.
//

import ARKit
import Foundation
import SceneKit
import SwiftUI
import UIKit

enum ARTextPanel {
    static func create(text: String, position: SCNVector3, scale: Float) -> SCNNode {
        let containerNode = SCNNode()
        
        // Text setup
        let textGeometry = SCNText(string: text, extrusionDepth: 0)
        textGeometry.font = UIFont.systemFont(ofSize: 1, weight: .regular)
        textGeometry.flatness = 0.005
        textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        textGeometry.materials = [createTextMaterial()]
        
        // Text positioning
        let textNode = SCNNode(geometry: textGeometry)
        let (min, max) = textGeometry.boundingBox
        textNode.position = SCNVector3(
            -(max.x - min.x)/2,
            -(max.y - min.y)/2,
            0
        )
        
        // Panel setup
        let panelNode = createBackgroundPanel(width: max.x - min.x + 0.4,
                                              height: max.y - min.y + 0.2)
        panelNode.position = SCNVector3(0, 1, -0.001)
        
        // Assembly
        containerNode.addChildNode(panelNode)
        containerNode.addChildNode(textNode)
        containerNode.position = position
        containerNode.scale = SCNVector3(scale, scale, scale)
        
        // Billboard constraint
        containerNode.constraints = [SCNBillboardConstraint()]
        
        return containerNode
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
        let panel = SCNPlane(width: CGFloat(width), height: CGFloat(height))
        let material = SCNMaterial()
        material.diffuse.contents = createGlassmorphicBackground()
        material.isDoubleSided = true
        material.lightingModel = .constant
        panel.materials = [material]
        return SCNNode(geometry: panel)
    }
    
    private static func createGlassmorphicBackground() -> UIImage {
        let size = CGSize(width: 800, height: 400)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let context = UIGraphicsGetCurrentContext()!
        
        // Create rounded rect path
        let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size),
                                cornerRadius: 40)
        context.addPath(path.cgPath)
        
        // Add gradient
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [
                                      UIColor(white: 0, alpha: 0.7).cgColor,
                                      UIColor(white: 0, alpha: 0.5).cgColor
                                  ] as CFArray,
                                  locations: [0.0, 1.0])!
        
        context.clip()
        context.drawLinearGradient(gradient,
                                   start: .zero,
                                   end: CGPoint(x: size.width, y: size.height),
                                   options: [])
        
        // Add glow
        context.setStrokeColor(UIColor(white: 1, alpha: 0.2).cgColor)
        context.setLineWidth(2)
        path.stroke()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
}
