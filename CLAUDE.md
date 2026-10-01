# CLAUDE.md

Guidance for Claude Code, and for anyone else, working in this repository.

## What this is

Speed Test is an iOS, iPadOS and macOS app. It fetches the list of public speed-test servers, picks the five
closest to the device, pings them over real ICMP, and measures download and upload speed on the one with the
lowest latency. SwiftUI and The Composable Architecture (TCA) on top of a small local Swift package.

## Layout

- `SpeedTest/`: the app target (`@main`, scenes, assets). Kept thin.
- `SpeedTestPackage/`: all the real code, in five modules.
  - `ICMP`: ICMP echo over unprivileged datagram sockets. No third-party dependencies.
  - `SpeedTestKit`: the dependency clients of a run, the transfer meter and the pure rules (server
    selection, throughput sampling, error mapping). No UI and no TCA.
  - `DesignSystem`: formatting, colors, button and card styles, the speed chart. Takes plain values.
  - `HistoryFeature`: past results in SQLite through SQLiteData, with a reducer and a list.
  - `SpeedTestFeature`: the reducer that drives a run step by step, and the screen.
- `SpeedTestUITests/`: two XCUITest smoke tests against a scripted run.
- `docs/DESIGN.md`: the technical design.

## Build and test

Run from the repository root. The package is built and tested with `xcodebuild`, not `swift build`/`swift test`:
SwiftPM on the command line doesn't compile String Catalogs or generate their symbols.

```bash
# All package tests on macOS (run inside SpeedTestPackage/)
xcodebuild test -scheme SpeedTestPackage-Package -destination 'platform=macOS' -skipMacroValidation

# One test target, or one suite
xcodebuild test -scheme SpeedTestPackage-Package -destination 'platform=macOS' -skipMacroValidation \
  -only-testing:ICMPTests
xcodebuild test -scheme SpeedTestPackage-Package -destination 'platform=macOS' -skipMacroValidation \
  -only-testing:SpeedTestKitTests/TransferMeterTests

# Package tests on the iOS simulator (run inside SpeedTestPackage/)
xcodebuild test -scheme SpeedTestPackage-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -skipMacroValidation

# The app
xcodebuild build -project SpeedTest.xcodeproj -scheme SpeedTest \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -skipMacroValidation
xcodebuild build -project SpeedTest.xcodeproj -scheme SpeedTest -destination 'platform=macOS' \
  -skipMacroValidation CODE_SIGNING_ALLOWED=NO

# Format and lint (both must be clean before a commit)
./swiftformat.sh && ./swiftlint.sh
```

The tools are pinned in the `Mintfile`; `mint bootstrap` installs them.

## Toolchain

- Swift 6.3 tools version, Swift 6 language mode, iOS 17 and macOS 14 minimum.
- Developed with Xcode 26.6. CI also builds with Xcode 27.0, so nothing may need Swift 6.4
  (no `await` inside `defer`, no `some P?` without parentheses, no `@diagnose`).
- Every package target enables `NonisolatedNonsendingByDefault` and `InferIsolatedConformances`.
  The package does not use default main-actor isolation: the dependency macros don't allow it.
- No warnings-as-errors in `Package.swift`. CI fails on warnings in this repo's own sources instead.

## Conventions

**Reducers**
- `@Reducer public struct X: Sendable`. The macro adds the `Reducer` conformance; `Sendable` is needed because
  effects capture the reducer's dependencies.
- `@ObservableState public struct State: Equatable`, `public init() {}`.
- `Action: ViewAction` with an `@CasePathable enum View`, plus flat `xxxResponse(Result<T, any Error>)` cases.
- A `Reduce { state, action in switch … }` body, with a blank line before each `return .none`.
- Children: `Scope(\.child, action: \.child) { Child() }`; views: `store.scope(\.child, action: \.child)`.
  Never the `state:` label.
- Share logic with a method on the reducer that takes `inout State` and returns an `Effect<Action>` (one start helper
  for Start and Retry, say), never by sending another action with `.send`.

**Effects**
- `.run { [value = state.value] send in await send(.xResponse(Result { … })) }`.
- One cancel ID type per long-running effect: `struct FooId: Hashable, Sendable {}` with `.cancellable(id:)`. The effect
  that starts something restartable uses `cancelInFlight: true`.
- Time through `@Dependency(\.continuousClock)`, durations as static constants.
- The package enables TCA's `ComposableArchitecture2Deprecations` trait. Don't use what it or TCA 1.25 deprecate:
  `Effect.concatenate`, `Effect.map`, `.animation()`/`.debounce`/`.throttle` on effects, `store.publisher`,
  `Store.withState`, the reducer-builder `onChange`, `@Reducer(state:action:)`, `store.send(_:animation:)`,
  `store.send(_:transaction:)`, `Effect.transaction(_:)`, `Scope(state:action:)`, and calling `reduce(into:action:)`
  directly. In a `@ViewAction` view, `send(_:animation:)` forwards to the deprecated `store.send`, so it's out too.
- Animation: `await send(.x, animation: …)` in an effect, `withAnimation { _ = send(.x) }` in a view (`@ViewAction`
  warns about `store.send`; `_ =` drops the returned task).
- Never send an action synchronously while another action is being reduced.

**Dependencies**
- `@DependencyClient` structs with `@Sendable` closures; non-throwing endpoints get a default.
- Registered with `@DependencyEntry` in `extension DependencyValues`.
- Interface, live and scripted/test values in separate files.
- A live value that needs other dependencies resolves them with `@Dependency`, not through `init`. The macro's
  `init()` (every endpoint unimplemented) is the test value.
- The reducer owns the flow and every decision. A dependency wraps one piece of I/O, or one piece of concurrency that
  can't live in `State` (the transfer meter's live connection handle). No engine that runs the whole flow.

**Errors**
- Plain `throws`, not typed throws. `any Error` is written out.
- Every error is mapped to a `SpeedTestError` in one place: `SpeedTestError.mapping` for a run,
  `SpeedTestError.directoryMapping` for the directory and token requests. Both return `nil` for cancellation.

**Views**
- `@Bindable public var store` with `@ViewAction(for:)` and `send(…)`.
- `@State` only for plain view-local values, with the initial value at the declaration and never assigned in an
  `init` (in the iOS 27 SDK `@State` is a macro and that pattern doesn't compile).
- Sub-views as `private var x: some View` or small structs; `#Preview` for previews.
- Strings: see **Localization** below. Numbers built in code use `Text(verbatim:)`.
- Accessibility identifiers: `startStopButton`, `serverField`, `pingField`, `downloadField`, `uploadField`,
  `phaseLabel`, `bigNumber`.

**Localization** (English, the default, and Czech)
- Every user-facing string lives in its module's String Catalog, `Resources/Localizable.xcstrings` (format 1.1,
  processed in `Package.swift`), under a stable key named `area.meaning` (`ping.noReply`, `phase.downloading`),
  never the English text. Each key has a translator comment and both an `en` and a `cs` translation; add both in the
  same change as the code that uses it.
- Use the generated symbols, never string literals: `Text(.pingNoReply)` in views, `String(localized: .pingNoReply)`
  where a `String` is needed, `LocalizedStringResource` to pass text around (a reducer's `AlertState`, say). The
  symbols are internal to their module, so each module localizes its own strings.
- Values inside a sentence go into the key as arguments (`results.count` → `%lld results`); plurals use the
  catalog's plural variants (Czech has one, few and other), not `if` statements.
- Numbers, dates and durations use `FormatStyle` in the user's locale; units are SI symbols ("ms", "s", "km") and
  "Mbps". Functions that format take `locale: Locale = .current`, and tests pin the locale.
- The app target's `InfoPlist.xcstrings` translates the location permission texts and the display name.
- Tests that check a translation set `resource.locale` on the `LocalizedStringResource`:
  `String(localized:bundle:locale:)` ignores that locale when it picks the language.

**Tests**
- Swift Testing: `@MainActor @Suite struct XTests`, exhaustive `TestStore`.
- Dependencies through the `.dependency(…)` and `.dependencies { … }` test traits, or `withDependencies:`.
- Actions sent and received by key path: `store.send(\.view.startStopTapped)`.
- `TestClock`/`ImmediateClock` for time, `LockIsolated` for capturing calls. Tests never assert on wall-clock time
  and never sleep: control time with a test clock, so a slow machine can't make a test fail or pass.
- A test awaits what it started in its own body (iterate the stream there, or use a task group), never a
  `Task { … }` it then awaits with `.value`: a time limit cancels the test's task, not an unstructured one, so such a
  test hangs instead of failing.
- A suite that uses `TestClock` or `ImmediateClock` gets the `.mainSerialExecutor` trait (`TestSupport`), Point-Free's
  recommended way to test async code: every task runs in order on the main executor, so the clocks' yields can't be
  starved on a busy CI machine. Use the trait, not `withMainSerialExecutor` directly: the switch is process-wide, and
  the trait keeps it on until the last test using it has finished. A suite that creates a `TestStore` gets the trait
  too: a `TestStore` turns the switch on and, when released, puts back what it found, which could switch it off
  under another suite. `TestClock` wakes sleepers on time, so a rule about late wake-ups is tested as a pure
  function.
- Snapshot tests run locally only (references are recorded on one machine); CI skips them.
- Every test and every assertion must be able to fail for a plausible bug in this repository's code. No
  tautologies: don't restate a literal or a one-line computed property, don't test the standard library or a
  dependency, and don't round-trip our own encoder and decoder when fixtures already pin both directions.
- No overtesting: pin each rule once, at the lowest level that owns it (a parser rule in the parser's tests,
  not again in the session's and the pinger's). Tests at higher levels check the wiring between parts, not the
  rules inside them. Every case of a parameterized test must take a different path through the code.

**Style**
- The file header on every file:

  ```swift
  //
  //  FileName.swift
  //  ModuleName
  //
  //  Created by Premysl Vlcek on dd.MM.yyyy.
  //
  ```
- `public extension X {}` for public API in extensions. `MARK` sparingly.
- No `@unchecked Sendable`.
- HTTPS only: no `NSAppTransportSecurity` exceptions, and SwiftLint's `force_https` rule has no exceptions.

## Commits

- Small commits in the imperative mood. Each one builds and passes its tests.
- Plain messages: no `Co-Authored-By` trailers, no session links, no "Generated with" lines.
- Claude Code doesn't commit, push, tag or create repositories here. It leaves its changes in the working tree,
  shows `git status` and `git diff --stat`, and the maintainer reviews and commits.
