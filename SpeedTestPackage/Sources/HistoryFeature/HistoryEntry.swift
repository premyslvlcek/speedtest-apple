//
//  HistoryEntry.swift
//  HistoryFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import ComposableArchitecture
import Foundation

/// One finished run, as the history list shows it. The values are copied, not referenced: the server list
/// changes, a past result doesn't.
public struct HistoryEntry: Codable, Hashable, Identifiable, Sendable {
    public var date: Date
    public var serverProvider: String
    public var serverCity: String
    /// The chosen server's median ping; `nil` when it didn't answer ICMP.
    public var pingMilliseconds: Double?
    public var downloadMbps: Double
    /// `nil` when upload wasn't measured, or couldn't start.
    public var uploadMbps: Double?
    public var ipAddress: String?
    public var ipProvider: String?

    public init(
        recordedAt date: Date,
        serverProvider: String,
        serverCity: String,
        pingMilliseconds: Double?,
        downloadMbps: Double,
        uploadMbps: Double?,
        ipAddress: String?,
        ipProvider: String?
    ) {
        self.date = date
        self.serverProvider = serverProvider
        self.serverCity = serverCity
        self.pingMilliseconds = pingMilliseconds
        self.downloadMbps = downloadMbps
        self.uploadMbps = uploadMbps
        self.ipAddress = ipAddress
        self.ipProvider = ipProvider
    }

    /// Two runs never finish at the same instant.
    public var id: Date {
        date
    }
}

public extension SharedKey where Self == FileStorageKey<[HistoryEntry]>.Default {
    /// The finished runs, newest first, in a JSON file in Application Support. Tests and previews keep it in
    /// memory (`defaultFileStorage`).
    static var history: Self {
        Self[.fileStorage(.applicationSupportDirectory.appending(component: "history.json")), default: []]
    }
}
