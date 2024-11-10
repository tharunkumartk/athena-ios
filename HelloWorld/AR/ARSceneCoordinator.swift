//
//  ARSceneCoordinator.swift
//  HelloWorld
//
//  Created by Tharun Kumar on 11/9/24.
//

import ARKit
import Foundation
import SceneKit
import SwiftUI
import UIKit

class ARSceneCoordinator: NSObject, ARSCNViewDelegate {
    var arView: ARSCNView!
    var imageNode: SCNNode?
    var currentTextNode: SCNNode?
    var completedTextNodes: [SCNNode] = []
    var eye: Eye = .center
    let ipd: Float = 0.063
    
    func updateSpeechVisualization(currentText: String, completedSentences: [String]) {
        DispatchQueue.main.async {
            self.currentTextNode?.removeFromParentNode()
            self.completedTextNodes.forEach { $0.removeFromParentNode() }
            self.completedTextNodes.removeAll()
            
            if !currentText.isEmpty {
                let node = ARTextPanel.create(
                    text: currentText,
                    position: SCNVector3(x: 0, y: 0.2, z: -1),
                    scale: 0.09
                )
                self.arView.scene.rootNode.addChildNode(node)
                self.currentTextNode = node
            }
        }
    }
    
    func createImageNode() {
        let plane = SCNPlane(width: 0.3, height: 0.4)
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, 0, -0.5)
        
        let imageUrl = URL(string: "https://tharunkumar.xyz/static/1d669eb50394d8904683073b5be62826/fe92a/me.avif")!
        
        URLSession.shared.dataTask(with: imageUrl) { [weak self] data, _, _ in
            guard let data = data, let uiImage = UIImage(data: data) else { return }
            
            DispatchQueue.main.async {
                plane.firstMaterial?.diffuse.contents = uiImage
                plane.firstMaterial?.isDoubleSided = true
                
                self?.arView.scene.rootNode.addChildNode(node)
                self?.imageNode = node
            }
        }.resume()
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
