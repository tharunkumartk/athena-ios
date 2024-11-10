//
//  AnimationDelegate.swift
//  HelloWorld
//
//  Created by Tharun Kumar on 11/9/24.
//

import Foundation
import SwiftUI
import UIKit

class AnimationDelegate: NSObject, CAAnimationDelegate {
    private let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            completion()
        }
    }
}
