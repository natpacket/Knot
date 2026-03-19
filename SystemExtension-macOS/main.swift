//
//  main.swift
//  SystemExtension-macOS
//
//  Created by aa123 on 2026/3/19.
//  Copyright © 2026 Lojii. All rights reserved.
//

import Foundation
import NetworkExtension

autoreleasepool {
    NEProvider.startSystemExtensionMode()
}

dispatchMain()
