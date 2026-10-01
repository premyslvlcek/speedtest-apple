//
//  Platform.swift
//  DesignSystem
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import SwiftUI

#if canImport(UIKit)
    import UIKit

    extension Color {
        /// A color that follows the system light/dark appearance.
        static func adaptive(light: UInt32, dark: UInt32) -> Color {
            Color(uiColor: UIColor { traits in
                UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
            })
        }
    }

    extension UIColor {
        convenience init(rgb: UInt32) {
            self.init(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        }
    }

#elseif canImport(AppKit)
    import AppKit

    extension Color {
        /// A color that follows the system light/dark appearance.
        static func adaptive(light: UInt32, dark: UInt32) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return NSColor(rgb: isDark ? dark : light)
            })
        }
    }

    extension NSColor {
        convenience init(rgb: UInt32) {
            self.init(
                srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        }
    }
#endif
