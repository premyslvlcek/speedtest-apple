//
//  LoopbackTests.swift
//  ICMPTests
//
//  Created by Premysl Vlcek on 01.10.2026.
//

@testable import ICMP
import Testing

/// The real socket, against the loopback interface. No network is needed.
@Suite(.timeLimit(.minutes(1))) struct LoopbackTests {
    @Test func resolvesNumericAddressesToTheirFamily() async {
        #expect(await AddressResolver.resolve("127.0.0.1")?.family == .ipv4)
        #expect(await AddressResolver.resolve("::1")?.family == .ipv6)
    }

    @Test func pingsIPv4Loopback() async {
        let result = await Pinger(host: "127.0.0.1").ping()

        #expect(result.sent == 5)
        #expect(result.received == 5)
    }

    @Test func pingsIPv6Loopback() async {
        let result = await Pinger(host: "::1").ping()

        #expect(result.sent == 5)
        #expect(result.received == 5)
    }

    @Test func threePingersAtOnceEachGetAllTheirReplies() async {
        async let ipv4 = Pinger(host: "127.0.0.1").ping()
        async let ipv6 = Pinger(host: "::1").ping()
        async let secondIPv4 = Pinger(host: "127.0.0.1").ping()

        let results = await [ipv4, ipv6, secondIPv4]

        for result in results {
            #expect(result.received == 5)
        }
    }
}
