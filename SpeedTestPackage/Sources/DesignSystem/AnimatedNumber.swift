//
//  AnimatedNumber.swift
//  DesignSystem
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import SwiftUI

/// A number that counts to each new value instead of jumping. Inside an animation SwiftUI interpolates `value`
/// frame by frame and `content` draws every frame, so a speed going 186 → 205 reads 187, 188, … on the way.
public struct AnimatedNumber<Content: View>: View, Animatable {
    private var value: Double
    private let content: (Double) -> Content

    public init(_ value: Double, @ViewBuilder content: @escaping (Double) -> Content) {
        self.value = value
        self.content = content
    }

    public var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    public var body: some View {
        content(value)
    }
}
