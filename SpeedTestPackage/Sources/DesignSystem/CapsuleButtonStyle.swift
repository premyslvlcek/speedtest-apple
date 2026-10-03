//
//  CapsuleButtonStyle.swift
//  DesignSystem
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import SwiftUI

/// The pinned Start/Stop button: a full-width capsule, blue to start, muted red to stop.
public struct CapsuleButtonStyle: ButtonStyle {
    public enum Role: Sendable {
        case start
        case stop
    }

    private let role: Role

    public init(role: Role) {
        self.role = role
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(role == .start ? Color.white : Palette.error)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 16)
            .background(Capsule().fill(role == .start ? Palette.startFill : Palette.stopBackground))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
