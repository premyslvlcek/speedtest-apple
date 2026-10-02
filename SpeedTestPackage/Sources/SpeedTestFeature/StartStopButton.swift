//
//  StartStopButton.swift
//  SpeedTestFeature
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import DesignSystem
import SwiftUI

/// The one button, pinned in the same place in every state: Start / Stop / Run again / Try again.
struct StartStopButton: View {
    let title: SpeedTest.State.ButtonTitle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity)
        }
        .startStopButtonStyle(title == .stop ? .stop : .start)
        .accessibilityIdentifier("startStopButton")
    }

    private var label: Text {
        switch title {
        case .runAgain:
            Text(.buttonRunAgain)

        case .start:
            Text(.buttonStart)

        case .stop:
            Text(.buttonStop)

        case .tryAgain:
            Text(.buttonTryAgain)
        }
    }
}
