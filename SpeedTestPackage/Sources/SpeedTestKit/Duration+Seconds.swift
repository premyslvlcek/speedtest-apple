//
//  Duration+Seconds.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

public extension Duration {
    /// The duration as fractional seconds, for rates and labels.
    var inSeconds: Double {
        self / .seconds(1)
    }
}
