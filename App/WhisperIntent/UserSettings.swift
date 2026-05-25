import Foundation
import SwiftUI

/// User-facing defaults persisted in `UserDefaults`. PRD §5.9.
///
/// v1 ships a single user-tunable default: the silence threshold the AppIntent
/// suggests when no per-invocation value is provided. The previously-listed
/// "Show UI by default" toggle was dropped — AppIntent `@Parameter` defaults
/// are static and can't read `UserDefaults` at definition time, so the toggle
/// would have had no effect on the Shortcuts editor.
enum UserSettings {
  private static let silenceThresholdKey = "defaultSilenceThreshold"
  private static let onboardingCompletedKey = "onboardingCompleted"

  /// PRD §5.4 default. Must stay in sync with the `@Parameter` default in
  /// `TranscribeSpeechIntent`.
  static let defaultSilenceThreshold: Double = 2.0

  static var silenceThreshold: Double {
    get {
      let stored = UserDefaults.standard.double(forKey: silenceThresholdKey)
      return stored == 0 ? defaultSilenceThreshold : stored
    }
    set { UserDefaults.standard.set(newValue, forKey: silenceThresholdKey) }
  }

  static var onboardingCompleted: Bool {
    get { UserDefaults.standard.bool(forKey: onboardingCompletedKey) }
    set { UserDefaults.standard.set(newValue, forKey: onboardingCompletedKey) }
  }
}

@propertyWrapper
struct SilenceThresholdSetting: DynamicProperty {
  @AppStorage("defaultSilenceThreshold") private var stored: Double = UserSettings.defaultSilenceThreshold

  var wrappedValue: Double {
    get { stored == 0 ? UserSettings.defaultSilenceThreshold : stored }
    nonmutating set { stored = newValue }
  }

  var projectedValue: Binding<Double> {
    Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
  }
}
