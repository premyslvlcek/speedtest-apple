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

    @Test func threePingersAtOnceEachGetAllTheirReplies() async {
        // Real time: a generous timeout, so a busy CI machine can't turn a slow loopback reply into a loss.
        let configuration = PingConfiguration(timeout: .seconds(10))
        async let ipv4 = Pinger(host: "127.0.0.1").ping(configuration)
        async let ipv6 = Pinger(host: "::1").ping(configuration)
        async let secondIPv4 = Pinger(host: "127.0.0.1").ping(configuration)

        let results = await [ipv4, ipv6, secondIPv4]

        for result in results {
            #expect(result.received == 5)
        }
    }
}
