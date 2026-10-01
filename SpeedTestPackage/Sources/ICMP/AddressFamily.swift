//
//  AddressFamily.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// The IP version an address, a socket and a packet belong to.
public enum AddressFamily: Sendable, Equatable {
    case ipv4
    case ipv6
}
