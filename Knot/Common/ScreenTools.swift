//
//  ScreenTools.swift
//  CD_OldMusic
//
//  Created by darren on 2018/7/13.
//  Copyright © 2018年 陈亮陈亮. All rights reserved.
//

import UIKit

typealias ScreenToolsClouse = (UIDeviceOrientation)->()

class ScreenTools: NSObject {
    static let share = ScreenTools()

    var screenClouse: ScreenToolsClouse?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(receiverNotification), name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    @objc func receiverNotification(){
        let orient = UIDevice.current.orientation
        switch orient {
        case .portrait:
            screenClouse?(.portrait)
        case .portraitUpsideDown:
            screenClouse?(.portraitUpsideDown)
        case .landscapeLeft:
            screenClouse?(.landscapeLeft)
        case .landscapeRight:
            screenClouse?(.landscapeRight)
        default:
            break
        }
    }
}
