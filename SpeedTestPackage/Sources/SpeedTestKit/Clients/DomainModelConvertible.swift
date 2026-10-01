//
//  DomainModelConvertible.swift
//  SpeedTestKit
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// A decoded API answer that turns into one of the app's own types.
///
/// `DomainModel` says what it becomes, including whether that can fail: a directory entry the app can't use
/// becomes `nil`, a token always becomes a token.
protocol DomainModelConvertible {
    associatedtype DomainModel

    func toDomainModel() -> DomainModel
}
