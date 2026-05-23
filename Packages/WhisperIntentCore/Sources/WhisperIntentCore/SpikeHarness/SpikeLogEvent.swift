import Foundation

/// One observation emitted by the S1 spike harness while transcribing a sample
/// audio file. Captures wall-clock timing + the kind of WhisperKit callback
/// that fired + a small payload, so we can compute callback granularity
/// without keeping the full WhisperKit `TranscriptionProgress` graph around.
///
/// Sendable so it can cross actor boundaries on its way to a `@MainActor`
/// log view.
public struct SpikeLogEvent: Sendable, Identifiable {
  public enum Kind: String, Sendable {
    case harnessStart
    case modelLoadStart
    case modelLoadEnd
    case transcribeStart
    case modelState // WhisperKit's modelStateCallback
    case transcriptionState // WhisperKit's transcriptionStateCallback
    case progress // WhisperKit's per-token progress callback
    case segmentDiscovered // WhisperKit's segmentDiscoveryCallback
    case transcribeEnd
    case harnessError
  }

  public let id: UUID
  public let kind: Kind
  /// Seconds since the harness started for this run. More useful than absolute
  /// wall-clock for callback-frequency analysis.
  public let elapsed: TimeInterval
  /// Short, log-friendly description. The harness keeps this small on purpose:
  /// dumping full token arrays for a 5-minute transcript drowns the signal.
  public let summary: String

  public init(kind: Kind, elapsed: TimeInterval, summary: String) {
    id = UUID()
    self.kind = kind
    self.elapsed = elapsed
    self.summary = summary
  }
}

public extension SpikeLogEvent {
  /// Single-line text rendering used by the on-device log view and the dump
  /// file written to Documents/.
  var logLine: String {
    String(format: "%7.3fs  %-22s  %@", elapsed, kind.rawValue, summary)
  }
}
