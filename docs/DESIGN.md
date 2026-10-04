# Design

The technical design behind Speed Test: how the app is structured, the rules the test follows, and why.

## 1. Principles

- **The reducer owns the flow.** Locating, fetching servers, pinging, choosing, downloading and uploading are steps
  of the `SpeedTest` reducer. Each step's effect does one piece of I/O and sends the result back as an action; the
  reducer decides what happens next. Every decision is in one place and every step is visible in an exhaustive
  `TestStore` test.
- **A dependency wraps one piece of I/O, or one piece of concurrency that can't live in `State`.** The locator, the
  server directory, the ping service and the history client are plain I/O. The transfer meter is the one exception:
  it holds the live connections, races the first byte against the stall timeout and owns the 250 ms tick, none of
  which is a value.
- **Take dependencies for broad, well-maintained infrastructure; write small, domain-critical code yourself when the
  options are unmaintained.** Hence our own ICMP, and TCA and swift-dependencies for the rest.
- **Typed throws pay off in closed, synchronous code where the caller handles every case.** At an async boundary built
  on `URLSession` and streams they add conversions and no safety. The code uses plain `throws` and maps every error to
  `SpeedTestError` in one place.
- **The newest released versions, and each library's current idioms.** Swift 6 language mode, TCA with its 2.0
  deprecations switched on, `@DependencyClient` and `@DependencyEntry`, the Swift 6.2 concurrency features
  `NonisolatedNonsendingByDefault` and `InferIsolatedConformances`.

## 2. Modules

```
App target (iOS universal + macOS)
  └─▶ SpeedTestFeature ──▶ SpeedTestKit ──▶ ICMP
          ├─▶ HistoryFeature
          └─▶ DesignSystem   (also used by HistoryFeature)
```

| Module | Depends on | Purpose |
|---|---|---|
| `ICMP` | Darwin, Foundation | Sending and parsing ICMP echo requests, usable by any app. |
| `SpeedTestKit` | ICMP, CoreLocation, Network, swift-dependencies | The dependency clients of a run (live and scripted), the transfer meter, and the pure rules: server selection, throughput sampling, error mapping. No UI, no TCA. |
| `SpeedTestFeature` | SpeedTestKit, ICMP, HistoryFeature, DesignSystem, TCA | The reducer that drives a run, and the screen. It saves a finished run through `HistoryClient` and never sees where runs are kept. |
| `DesignSystem` | SwiftUI, Charts | Formatting, colors, the button and card styles, the animated number, the speed chart. It takes plain values. |
| `HistoryFeature` | DesignSystem, TCA | The history, a JSON file through `@Shared(.fileStorage)`; `HistoryClient` (save a run), the reducer and the sheet. |

The app target is thin: the scene and the localized Info.plist texts. The scene creates the root store once, and
prepares the dependencies right before it: for the UI test, the scripted clients and an in-memory history. One
multiplatform SwiftUI target covers iPhone, iPad and native macOS (not Mac Catalyst). The Mac uses a single `Window`,
and the iPad has multiple scenes off, so one window going to the background can't stop a test running in another.

## 3. The test flow

Each numbered step is one effect and one action back into the reducer.

1. **Locate.** Permission is requested on the first Start, not at launch. The locator waits for the user's answer
   with no timeout; a 10 s timeout starts only once authorization is resolved, so reading the system dialog never
   drops the test into approximate mode. The outcome is `.located`, `.notAuthorized` or `.unavailable`; anything but
   `.located` means approximate mode, not a failure. At the same time, `GET /api/v1/ip` looks up the public address
   and provider for the line under the card; it has its own effect, so a failed lookup only hides the line, and
   Stop doesn't cancel it.
2. **Fetch servers.** `GET /api/v2/servers?secured=only&latitude=…&longitude=…`, or only `secured=only` in approximate
   mode. The coordinates are rounded to two decimals (about 1 km), the accuracy the locator asks for. Entries with a
   duplicate URL, a non-`https` URL or a host outside `wifiman.me` are dropped while decoding: the app sends a token
   and 25 s of traffic to the server it picks, so it only goes to Ubiquiti's.
3. **Pick the candidates.** With a location: the 5 closest by great-circle distance, computed on the device (the
   directory's order isn't trusted). In approximate mode: up to 10 servers in the directory's order, with no
   distances. No servers at all is `.noServers`.
4. **Ping.** Each distinct host once, all hosts at once, 5 echo requests 100 ms apart with a 1 s timeout each. The
   result is the median round-trip time and the number of replies. Each host's result is an action, so the list fills
   in as replies arrive.
5. **Choose.** Once every host has answered: servers with at least 3 replies by lowest median, then servers with at
   least 1 reply, then the rest, nearest first. Ties go to the closer server (in approximate mode, the earlier one).
   If nothing replied, the nearest server is used, with the reason "ICMP blocked". The full order is kept for
   failover.
6. **Token.** `POST /api/v1/tokens` right before the download. A fresh token for every run; it lives 80 s and a run
   needs at most about 40 s, so there is no refresh logic.
7. **Download, 15 s** (section 4). Every sample is an action; the stream's end is another.
8. **Upload, 10 s**, only when "Measure upload too" is on (off by default, remembered in `@Shared(.appStorage)`). Same
   server, same token. If the upload can't start, or the server refuses it (upload bytes count as they're sent, so a
   refusal comes after the first byte), the run still finishes, with upload marked unavailable.
9. **Save.** A finished run goes to `HistoryClient.save`, which puts it first in the shared history: the server, the
   median ping, both averages and the address. A stopped, interrupted or failed run isn't saved. The history is a
   JSON array in Application Support: it's small and never queried, so a file does what a database
   would, without the dependency. If it ever needs queries or sync, SQLiteData is the next step.

**Stop** cancels every effect of the run at once (one cancel ID); ending the meter's stream cancels the transfer, its
connections and the network watch. The partial result is the last sample of whichever transfer was running. Start
straight after Stop begins a clean run: the start effect uses `cancelInFlight: true`.

**Background.** On iOS, the scene going to the background interrupts the run the same way. `.inactive` doesn't:
Control Center and the location prompt both make the scene inactive. On the Mac nothing interrupts but Stop.

**Units.** Megabits per second in decimal (10⁶). Values of 100 and above are whole numbers, smaller ones get one
decimal. Ping in whole milliseconds, "<1 ms" below one. Numbers are formatted in the user's locale.

## 4. Measuring throughput

| Piece | Job |
|---|---|
| `TransferSession` (the `URLSession` delegate) | Starts the parallel connections and adds up bytes behind a lock. Nothing else. |
| `TransferService` | The dependency that starts a session for a server and a direction, and returns a handle. No clock. |
| `ThroughputSampler` | Pure code: turns (time, total bytes) readings into samples. |
| `TransferMeter` | Waits for the first byte against the stall timeout, then owns the 250 ms tick on its injected clock, reads the counter, runs the sampler, and yields samples as an `AsyncThrowingStream`. |

- **Time and bytes start at the first byte.** The 15 s (10 s for upload) and every elapsed value count from there,
  and so do the bytes: what was counted before the clock started (the first chunk, and anything that arrived while the
  meter got going) is left out. Connection setup never counts. Before it the screen says "Connecting…".
- **A sample every 250 ms:** elapsed time, total bytes, the current speed over the last second (or over the time
  since the first byte, when that's shorter, so the first samples aren't under-reported), and the average since the
  first byte. Ticks are multiples of the interval from the first byte, so they don't drift; a late wake-up skips the
  ticks it missed instead of reporting them at once. The speeds use the time the bytes were read at, so a late last
  wake-up doesn't count extra bytes over the shorter time.
- **The upload's average leaves out its first second.** Upload bytes count when they're handed to the network stack,
  and `URLSession` reports them in 2 MiB steps per connection, ahead of what has actually left. Measured against the
  server's own `{"size": N}` replies, that head start made a 10 s upload read up to about 5 % high at 140 Mbps, and
  would be far more on a slow uplink. It stays about the same all along, so averaging from 1 s to 10 s cancels it.
  The meter reads during that second but sends no samples, so the screen says "Connecting…" a second longer instead
  of showing the head start as a spike (a 40 Mbps line read 296 Mbps in its first sample).
  The download needs none of this: its bytes are counted as they arrive, in chunks of tens of kilobytes.
- **The result** is the last sample, at exactly the duration. A partial result (Stop, an interruption) is defined the
  same way: the last sample's average.
- **Connections:** 4 in parallel. Download requests `GET /download?size=50000000&nc=<random>`; a connection that
  finishes a body asks again at once. Upload posts one 8 MB random buffer, reused. A connection that fails after the
  first byte isn't retried.
- **Failover, once, before the first byte:** when every connection fails or is refused, or after 5 s with no data.
  The reducer switches to the next server in the order, on another host when there is one (a second port of a host
  that just failed would most likely fail the same way). If that fails too, the run fails with `.transferFailed`, or
  `.offline` when the device is offline.
- **After the first byte:** all connections failed means `.connectionLost`; a change of the primary network interface
  means `.networkChanged`. Both are interruptions with a partial result.
- **Honest `URLSession` settings:** an ephemeral configuration with no cache, `Accept-Encoding: identity`, a per-host
  connection limit equal to the connection count, and one session per transfer, invalidated at the end.
- **A non-2xx answer** (401, 429, 5xx) from a test server fails that connection, and the bytes it had counted are
  taken back out (upload bytes count as they're sent, before the status arrives). An upload whose failed connections
  were all refused this way ends as "unavailable", not as a lost connection.

## 5. Concurrency

- The hot path never goes through the reducer. Delegate callbacks add to a counter behind `OSAllocatedUnfairLock`;
  the transfer meter reads it every 250 ms and the reducer gets one action per sample.
- The pinger and the transfer meter take a clock, so tests use a test clock and never wait for real time.
- The first-byte race is decided by what happened, not by which task finished first: a real connection error always
  wins, and a timeout counts only if it was the timeout that cancelled the connections.
- Cancellation is cooperative throughout. Each step is a structured effect; sockets are closed, requests cancelled
  and the path monitor stopped when the effect is cancelled, which tests verify with fakes that record it.
- Swift 6 language mode with no `@unchecked Sendable`.

## 6. The ICMP module

- `EchoMessage` builds echo requests (IPv4 type 8 with an RFC 1071 checksum; IPv6 type 128, checksum left to the
  kernel) and parses replies (IPv4: the IP header is stripped by its length nibble; IPv6: no header).
- `Pinger` resolves the host with `getaddrinfo` (`PF_UNSPEC`, `AI_DEFAULT`), opens a `SOCK_DGRAM` socket that is
  `connect()`ed to the target, picks a random identifier and payload token, and reads replies with a
  `DispatchSourceRead` that timestamps each one in the handler.
- `PingSession` is the matching and timeout logic as a pure value type, tested without any socket; the pinger is
  tested against a fake socket and against the real loopback on IPv4 and IPv6.

## 7. The screen

- A phase label in sentence case ("Pinging 5 servers…", "Connecting…", "Downloading · 7.4 s"), a big number with the
  live speed, and a Swift Charts area graph of the current transfer. When the test ends, the big number shows the
  download average and the graph the download with a dashed line at the average.
- The big number, the elapsed seconds and the Download and Upload rows count smoothly between samples (an `Animatable`
  view, linear over the sample interval), so the number and its row agree once each count ends. The graph's newest point
  grows the same way; the y axis steps through round values (1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10 × 10ⁿ), so it doesn't
  move with every sample. All of it is off under Reduce Motion.
- One card whose first three rows are server, ping and download; upload is a fourth row, shown only when upload is
  measured. The Download (and Upload) row shows the current speed during its transfer and the average after it, as the
  brief describes the download field. At accessibility text sizes a row stacks its value under its title and wraps it.
- The "Measure upload too" switch sits below the card and is disabled during a run.
- Start/Stop is pinned outside the scrolling content, so it's always in the same place. Its title follows the run:
  Start, Stop, then Run Again once a run has ended (finished or not), or Try Again after a failure. Button fills keep
  white text at 4.5:1 or more in light and dark mode.
- **Layout:** one column in compact width (iPhone, iPad Split View); two panes in regular width (iPad, an open iPhone
  Duo) and always on the Mac: the measurement and the button on the left, the upload switch and the servers on the
  right. The measurement pane takes the space; the servers pane stays at most 320 pt wide. The rule reads the
  horizontal size class, not the device type. On the Mac the button is a large prominent push button, and a Test menu
  mirrors it on ⌘R (Start Test, Stop Test, Run Test Again, Try Again) and opens History on ⌘Y. While the history sheet
  is open both are disabled, except that ⌘R still stops a run.
- Under the card, one quiet line: "Your IP 203.0.113.7 · provider".
- A History button in the toolbar opens a sheet with the finished runs, newest first: server, date, download (and
  upload), ping and the address. Swipe to delete a row; Clear asks first, then deletes them all. Done sits on the
  trailing side and Clear on the leading side, as the HIG places them. The main screen itself stays the brief's
  single screen.
- Below: the pinged servers, filling in live with their distance and ping; the chosen one is marked.
- **States:** idle; locating and pinging; finished; interrupted, with the partial average and the reason; degraded,
  with inline notes (location off, location unavailable, ICMP blocked); failed, with an inline message and Try Again.
  No modal alerts.
- On iOS the screen stays awake during a test and a haptic marks the end. VoiceOver reads values with units ("6 ms,
  3 of 5 replies" rather than "3/5") and announces the end of a run once: the averages, the reason it stopped with what
  was measured, or the error. Dynamic Type, light and dark mode are respected; numbers and units never split across
  lines.
- **Localization:** English (the default) and Czech. Strings live in each module's String Catalog under stable keys
  and are used through Xcode's generated symbols; plurals use the catalog's variants (Czech has one, few and other).
  The app target's own `InfoPlist.xcstrings` translates the permission texts and is what makes iOS offer Czech at
  all.

## 8. Errors

| Kind | Cases | What the user sees |
|---|---|---|
| Degraded (the test goes on) | no location; some pings time out; no ping replies at all | an inline note |
| Interrupted (partial result) | Stop; background on iOS; network changed; connection lost | the partial average and the reason |
| Failed | offline, directory unavailable, rate limited, no servers, transfer failed | an inline message and Try Again |

| Phase | What happened | Result |
|---|---|---|
| Directory or token | no internet, data not allowed, roaming off, connection lost | offline |
| Directory or token | HTTP 429 | rate limited, no automatic retry |
| Directory or token | timeout, DNS failure, any other non-2xx, undecodable body | directory unavailable |
| Transfer, before the first byte | every connection fails, or 5 s without data | fail over once, then transfer failed |
| Transfer, after the first byte | one connection fails | the others continue |
| Transfer, after the first byte | every connection failed | connection lost |
| Transfer, after the first byte | the primary interface changed | network changed |

## 9. Testing

- **ICMP:** packets against bytes captured from real replies; the matching logic as a pure type; the pinger against
  a fake socket and the real loopback, including three pingers running at once.
- **SpeedTestKit:** server selection tables (haversine against known distances, ties, duplicate hosts, approximate
  mode, ranking, the failover target); decoding the real directory JSON and the error mapping through a stubbed
  `URLProtocol`; the sampler; the transfer meter's sampling, the bytes before t0, failures, a refused upload,
  interruptions, and both rules of the first-byte race (a real error beats a coinciding timeout; a byte after the
  timeout cancelled the connections is a stall), against a test clock; and the upload's warm-up on a clock that wakes
  late, as a real one does.
- **SpeedTestFeature:** exhaustive `TestStore` tests for the run from Start to the chosen server, the transfers,
  failover, Stop while connecting, downloading and uploading, background, retry and the upload switch, with fakes
  for every dependency. A dependency a test didn't provide fails the test if the reducer calls it. The screen's text
  and the graph's data are tested as plain functions of the state. Which runs are saved, and what an entry holds, is
  recorded by a fake `HistoryClient`.
- **HistoryFeature:** the live client putting a new run first, deleting a row, Clear with its confirmation, and
  Done, against the in-memory file storage every test gets.
- **UI test:** one smoke test of the real app, launched with `-scriptedRun` (Debug builds only): the four dependency
  clients are swapped for their scripted versions and the history is kept in memory, so a run takes a few seconds
  with no network, location or ICMP, and never touches the saved history. It checks only the wiring no package test
  can: a run fills the three fields and the address, and the run lands in the history. What a run
  does, Stop included, is pinned in the reducer tests.
- **Time:** tests never sleep or read the wall clock. They use `TestClock` on the main serial executor, so a slow CI
  machine can't make a test pass or fail.
- **CI:** Xcode 26.6 and Xcode 27.0; the package tests on macOS and the iOS simulator, the iOS and macOS app builds,
  the UI test (its screenshot is kept as an artifact), and lint. Every job fails on a compiler warning in this
  repository's sources.

## 10. Smaller decisions

- **NAT64.** Addresses come from `getaddrinfo` with `PF_UNSPEC` and `AI_DEFAULT`, which synthesizes IPv6 addresses on
  IPv6-only networks; ICMPv6 is handled throughout. Ubiquiti's directory and test servers are IPv4-only today, so on
  such a network everything goes through NAT64. If a carrier's NAT64 doesn't pass ICMPv6, no server answers and the
  app uses the nearest one, saying why.
- **HTTPS throughout.** With `secured=only` the directory returns `https://…wifiman.me` addresses with valid
  certificates, on the same unusual ports. No App Transport Security exception.
- **Honest counters.** Requests send `Accept-Encoding: identity`, so a compressing server can't inflate the number;
  every session is ephemeral with no cache. A non-2xx answer takes its bytes back out; the current speed is never
  shown below zero.
- **What the app doesn't do.** It doesn't send results anywhere (the web client posts them to Ubiquiti), keeps no
  cookies or cache, and makes one server-list request, one token request and one IP lookup per run, with no automatic
  retries. A 429 from the directory shows "busy, try again in a minute".
- **Upload is opt-in.** The brief's test is the 15 s download, so that's what Start runs; "Measure upload too" adds a
  10 s upload on the same server and is remembered (`@Shared(.appStorage)`).

