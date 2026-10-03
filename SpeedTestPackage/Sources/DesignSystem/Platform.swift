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

public extension View {
    /// The Start/Stop look: the capsule on iOS, a large prominent push button on the Mac.
    @ViewBuilder
    func startStopButtonStyle(_ role: CapsuleButtonStyle.Role) -> some View {
        #if os(macOS)
            buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(role == .start ? Palette.startFill : Palette.stopFill)
        #else
            buttonStyle(CapsuleButtonStyle(role: role))
        #endif
    }
}
