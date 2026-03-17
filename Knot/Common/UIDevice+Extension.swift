//
//  UIDevice+Extension.swift
//  Knot
//
//  Created by LiuJie on 2019/4/28.
//  Copyright © 2019 Lojii. All rights reserved.
//

import UIKit
public extension UIDevice {
    /// Detect devices with home indicator (iPhone X and later)
    static func isX() -> Bool {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.bottom > 0
        }
        return UIScreen.main.bounds.height > 800
    }

    static func isIOS11() -> Bool {
        return true // iOS 15+ is always >= iOS 11
    }
}
