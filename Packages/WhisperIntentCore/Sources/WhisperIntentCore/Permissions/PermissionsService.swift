import AVFAudio
import Foundation

/// Microphone permission status + request. Wraps
/// `AVAudioApplication.shared.recordPermission` and `requestRecordPermission`.
/// See `docs/TDD.md` §9.
public final class PermissionsService: Sendable {
  public enum MicrophoneStatus: Sendable, Equatable {
    case undetermined
    case granted
    case denied
  }

  public init() {}

  /// Current microphone permission status.
  public func microphoneStatus() -> MicrophoneStatus {
    Self.map(AVAudioApplication.shared.recordPermission)
  }

  /// Requests microphone permission. Resolves with the post-request status.
  /// If permission is already granted or denied, returns the current status
  /// without showing the system prompt.
  public func requestMicrophone() async -> MicrophoneStatus {
    let current = microphoneStatus()
    if current != .undetermined { return current }

    let granted = await AVAudioApplication.requestRecordPermission()
    return granted ? .granted : .denied
  }

  private static func map(_ permission: AVAudioApplication.recordPermission) -> MicrophoneStatus {
    switch permission {
    case .granted: .granted
    case .denied: .denied
    case .undetermined: .undetermined
    @unknown default: .undetermined
    }
  }
}
