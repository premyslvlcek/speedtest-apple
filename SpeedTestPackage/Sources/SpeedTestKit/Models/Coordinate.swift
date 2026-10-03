//
//  Coordinate.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

import Foundation

/// A point on Earth in degrees (WGS 84).
public struct Coordinate: Sendable, Hashable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance in meters (haversine on the mean Earth radius). Computed on the device, because
    /// the directory's own ordering isn't by distance when it locates us by IP.
    ///
    /// Not `CLLocation.distance(from:)`: it can return wrong values when several threads call it for the first
    /// time at once. This is plain arithmetic, so it's exact to repeat and safe from any thread. Within 0.5% of
    /// the ellipsoid distance, which never changes which servers are nearest.
    public func distance(to other: Coordinate) -> Double {
        let latitude1 = latitude.radians
        let latitude2 = other.latitude.radians
        let deltaLatitude = latitude2 - latitude1
        let deltaLongitude = (other.longitude - longitude).radians

        // hav(θ) = hav(Δφ) + cos φ1 · cos φ2 · hav(Δλ), where θ is the central angle between the two points.
        let haversineOfAngle = Self.haversine(deltaLatitude)
            + cos(latitude1) * cos(latitude2) * Self.haversine(deltaLongitude)
        let centralAngle = 2 * atan2(sqrt(haversineOfAngle), sqrt(1 - haversineOfAngle))
        return Self.earthRadius * centralAngle
    }

    /// Mean Earth radius in meters (IUGG).
    private static let earthRadius = 6_371_008.8

    /// The haversine function, hav(θ) = sin²(θ / 2), which gives the formula its name.
    private static func haversine(_ angle: Double) -> Double {
        let halfSine = sin(angle / 2)
        return halfSine * halfSine
    }
}

private extension Double {
    /// This angle, given in degrees, in radians.
    var radians: Double {
        self * .pi / 180
    }
}
