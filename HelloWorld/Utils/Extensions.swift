//
//  Extensions.swift
//  HelloWorld
//
//  Created by Tharun Kumar on 11/9/24.
//

import ARKit
import Foundation
import SceneKit
import SwiftUI
import UIKit

extension simd_float4x4 {
    init(translation: SIMD3<Float>) {
        self.init(simd_float4(1, 0, 0, 0),
                  simd_float4(0, 1, 0, 0),
                  simd_float4(0, 0, 1, 0),
                  simd_float4(translation.x, translation.y, translation.z, 1))
    }
}
