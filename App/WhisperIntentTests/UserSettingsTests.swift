import XCTest
@testable import WhisperIntent

/// Verifies the persisted-defaults behaviour of `UserSettings`. The store is
/// `UserDefaults.standard`, so each test clears the relevant keys before and
/// after running to avoid leaking state between tests or into the real app.
final class UserSettingsTests: XCTestCase {
  private let silenceKey = "defaultSilenceThreshold"
  private let onboardingKey = "onboardingCompleted"

  override func setUp() {
    super.setUp()
    UserDefaults.standard.removeObject(forKey: silenceKey)
    UserDefaults.standard.removeObject(forKey: onboardingKey)
  }

  override func tearDown() {
    UserDefaults.standard.removeObject(forKey: silenceKey)
    UserDefaults.standard.removeObject(forKey: onboardingKey)
    super.tearDown()
  }

  // MARK: - silenceThreshold

  func testSilenceThresholdReturnsDefaultWhenUnset() {
    XCTAssertEqual(
      UserSettings.silenceThreshold,
      UserSettings.defaultSilenceThreshold,
      "with no stored value, the getter should return the documented default"
    )
  }

  func testSilenceThresholdReturnsDefaultWhenStoredValueIsZero() {
    // 0 is the sentinel UserDefaults returns for an unset Double; the getter
    // treats it as "use the default" so the AppIntent never sees 0s.
    UserDefaults.standard.set(0.0, forKey: silenceKey)
    XCTAssertEqual(
      UserSettings.silenceThreshold,
      UserSettings.defaultSilenceThreshold
    )
  }

  func testSilenceThresholdRoundTrips() {
    UserSettings.silenceThreshold = 4.5
    XCTAssertEqual(UserSettings.silenceThreshold, 4.5, accuracy: 0.0001)
  }

  func testSilenceThresholdRoundTripPersistsAcrossLookups() {
    UserSettings.silenceThreshold = 3.0
    XCTAssertEqual(UserSettings.silenceThreshold, 3.0, accuracy: 0.0001)
    XCTAssertEqual(UserSettings.silenceThreshold, 3.0, accuracy: 0.0001)
  }

  // MARK: - onboardingCompleted

  func testOnboardingCompletedDefaultsToFalse() {
    XCTAssertFalse(UserSettings.onboardingCompleted)
  }

  func testOnboardingCompletedRoundTrip() {
    UserSettings.onboardingCompleted = true
    XCTAssertTrue(UserSettings.onboardingCompleted)

    UserSettings.onboardingCompleted = false
    XCTAssertFalse(UserSettings.onboardingCompleted)
  }
}
