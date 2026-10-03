//
//  Palette.swift
//  DesignSystem
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import SwiftUI

/// The app's colors. Accents are custom; backgrounds and secondary text are system colors,
/// so the screen follows light and dark mode and matches native grouped lists.
public enum Palette {
    public static let download = Color.adaptive(light: 0x0A6CFF, dark: 0x3D8BFF)
    public static let upload = Color.adaptive(light: 0x7A4DFF, dark: 0x9B7BFF)
    public static let success = Color.adaptive(light: 0x248A3D, dark: 0x34C759)
    public static let warning = Color.adaptive(light: 0x8F4B00, dark: 0xFFB340)
    public static let error = Color.adaptive(light: 0xB00012, dark: 0xFF6B6B)
    /// Fills behind white button text: at least 4.5:1 in light and dark mode, which the brighter accents aren't.
    public static let startFill = Color.adaptive(light: 0x0062E6, dark: 0x0062E6)
    public static let stopFill = Color.adaptive(light: 0xC00014, dark: 0xC00014)
    public static let stopBackground = Color.adaptive(light: 0xE9EAEE, dark: 0x2A2F3A)
    public static let secondaryText = Color.secondary

    #if canImport(UIKit)
        public static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
        public static let screenBackground = Color(uiColor: .systemGroupedBackground)
    #else
        public static let cardBackground = Color(nsColor: .controlBackgroundColor)
        public static let screenBackground = Color(nsColor: .windowBackgroundColor)
    #endif
}
