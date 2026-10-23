import Foundation
import Darwin

// Framework-free checks run with Command Line Tools; full Xcode/XCTest is not required.
var failures = 0
func record(_ okay: Bool, _ message: String, file: StaticString, line: UInt) {
    if !okay { failures += 1; print("FAIL \(file):\(line) \(message)") }
}
func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) { record(value, "Expected true", file: file, line: line) }
func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) { record(!value, "Expected false", file: file, line: line) }
func expectNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) { record(value == nil, "Expected nil", file: file, line: line) }
func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) { record(actual == expected, "Expected \(expected), got \(actual)", file: file, line: line) }
func expectThrows<T>(_ expression: @autoclosure () throws -> T, _ message: String = "Expected an error", file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try expression(); record(false, message, file: file, line: line) } catch {}
}
func expectNoThrow<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    do { _ = try expression() } catch { record(false, "Unexpected error: \(error)", file: file, line: line) }
}
enum CheckFailure: Error { case missingValue }
func require<T>(_ value: T?) throws -> T { guard let value else { throw CheckFailure.missingValue }; return value }

let timer = BreakSchedulerTests()
let chat = ChatProtocolTests()
let geometry = GeometryTests()
let checks: [(String, () throws -> Void)] = [
    ("90-minute boundary and one-shot presentation", timer.testNinetyMinuteBoundaryAndPresentationIsOneShot),
    ("snooze keeps elapsed and excludes inactive time", timer.testSnoozeKeepsElapsedAndUsesOnlyActiveTime),
    ("short and sustained breaks", timer.testShortBreakResumesAndFiveMinuteBreakResets),
    ("manual pause is not rest", timer.testManualPauseDoesNotCountAsRest),
    ("reset and invalid elapsed input", timer.testSkipAndRestBothResetButInvalidDeltasDoNotChangeTime),
    ("checkpoint recovery", timer.testCheckpointRestoresElapsedButNotPresentedOrInactiveGap),
    ("endpoint normalization", chat.testEndpointNormalizesBaseVersionAndFullEndpoint),
    ("remote HTTP and credential rejection", chat.testRemoteHTTPAndEmbeddedCredentialsAreRejected),
    ("request body", chat.testRequestContainsCurrentConversationAndStreamingChoice),
    ("SSE boundaries and DONE", chat.testSSEHonorsEventBoundaryCommentsAndDone),
    ("multiline SSE and role-only chunks", chat.testSSEMultilineDataAndRoleOnlyChunks),
    ("malformed SSE and provider error", chat.testMalformedAndProviderErrorFailClearly),
    ("nonstreaming response", chat.testNonstreamingCompletionRejectsMissingAnswer),
    ("raw byte SSE preserves boundaries and Unicode", chat.testByteStreamPreservesBlankBoundariesAndUnicode),
    ("disconnected screen placement", geometry.testDisconnectedMonitorPositionClampsToVisibleScreen),
    ("oversized and negative-coordinate placement", geometry.testOversizedWindowFitsAndNegativeDisplayCoordinatesRemainValid)
]
for (name, check) in checks {
    let previous = failures
    do { try check() } catch { failures += 1; print("FAIL \(name): \(error)") }
    if failures == previous { print("PASS \(name)") }
}
print("\(checks.count) checks, \(failures) failures")
exit(failures == 0 ? 0 : 1)
