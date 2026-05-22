import Foundation

/// Microphone permission status + request. Implementation deferred to M3.
/// See `docs/TDD.md` §9.
public final class PermissionsService: Sendable {
  public enum MicrophoneStatus: Sendable, Equatable {
    case undetermined
    case granted
    case denied
  }

  public init() {}

  public func microphoneStatus() -> MicrophoneStatus {
    fatalError("Unimplemented (M3).")
  }

  public func requestMicrophone() async -> MicrophoneStatus {
    fatalError("Unimplemented (M3).")
  }
}
