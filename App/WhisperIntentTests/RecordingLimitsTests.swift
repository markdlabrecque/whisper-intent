import XCTest
@testable import WhisperIntent

/// Sanity tests for the `RecordingLimits` constants. These don't exercise
/// behaviour so much as guard against accidental edits that would break the
/// downstream assumptions in `RecordingSheet` (cap-relative warning colours)
/// and `TranscribeSpeechIntent` (cap passed into `RecordingConfig`).
final class RecordingLimitsTests: XCTestCase {
  func testMaxRecordingSecondsIsPositive() {
    XCTAssertGreaterThan(RecordingLimits.maxRecordingSeconds, 0)
  }

  func testThresholdsAreFractions() {
    XCTAssertGreaterThan(RecordingLimits.warningThreshold, 0)
    XCTAssertLessThan(RecordingLimits.warningThreshold, 1)
    XCTAssertGreaterThan(RecordingLimits.criticalThreshold, 0)
    XCTAssertLessThan(RecordingLimits.criticalThreshold, 1)
  }

  func testWarningPrecedesCritical() {
    // The recording sheet shifts to orange at warning, red at critical.
    // Reversing them would invert the user-facing severity.
    XCTAssertLessThan(
      RecordingLimits.warningThreshold,
      RecordingLimits.criticalThreshold,
      "warning threshold must come before critical threshold"
    )
  }

  func testWarningThresholdIsHighEnoughToBeReached() {
    // Sanity: 80% of a 10-minute cap is 8 minutes, well within reach during
    // normal use. If someone sets warningThreshold < 0.5, that's almost
    // certainly a bug.
    XCTAssertGreaterThan(RecordingLimits.warningThreshold, 0.5)
  }
}
