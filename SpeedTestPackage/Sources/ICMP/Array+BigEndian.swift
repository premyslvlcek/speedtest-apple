//
//  Array+BigEndian.swift
//  ICMP
//
//  Created by Premysl Vlcek on 01.10.2026.
//

/// Reading and writing 16-bit numbers as two bytes, high byte first (network byte order).
extension [UInt8] {
    /// Appends `value` as two bytes, high byte first.
    mutating func appendBigEndian(_ value: UInt16) {
        append(UInt8(value >> 8))
        append(UInt8(value & 0xFF))
    }

    /// Overwrites the two bytes at `index` with `value`, high byte first.
    mutating func setBigEndian(_ value: UInt16, at index: Int) {
        self[index] = UInt8(value >> 8)
        self[index + 1] = UInt8(value & 0xFF)
    }

    /// Reads the two bytes at `index` as one number, high byte first.
    func bigEndianUInt16(at index: Int) -> UInt16 {
        UInt16(self[index]) << 8 | UInt16(self[index + 1])
    }
}
