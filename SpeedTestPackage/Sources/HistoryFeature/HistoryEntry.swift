//
//  HistoryEntry.swift
//  HistoryFeature
//
//  Created by Premysl Vlcek on 02.10.2026.
//

import Foundation
import SQLiteData

/// One finished run, as the history list shows it. The values are copied, not referenced: the server list
/// changes, a past result doesn't.
@Table
public struct HistoryEntry: Hashable, Identifiable, Sendable {
    public let id: Int
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
}

/// The macro doesn't carry `Sendable` or `Equatable` over to the draft: one is needed to write it from an effect,
/// the other to compare what a run saved.
extension HistoryEntry.Draft: Sendable, Equatable {}

public extension HistoryEntry.Draft {
    /// A new entry for a run that just finished. Public because the macro's memberwise initializer is internal,
    /// and the speed-test feature, another module, records the runs.
    init(
        recordedAt date: Date,
        serverProvider: String,
        serverCity: String,
        pingMilliseconds: Double?,
        downloadMbps: Double,
        uploadMbps: Double?,
        ipAddress: String?,
        ipProvider: String?
    ) {
        self.init(
            date: date,
            serverProvider: serverProvider,
            serverCity: serverCity,
            pingMilliseconds: pingMilliseconds,
            downloadMbps: downloadMbps,
            uploadMbps: uploadMbps,
            ipAddress: ipAddress,
            ipProvider: ipProvider
        )
    }
}
