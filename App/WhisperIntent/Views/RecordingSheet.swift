import SwiftUI
import WhisperIntentCore

/// Foreground recording UI presented when the AppIntent runs with `showUI = true`.
/// Binds to `TranscriptionSession.state` and transitions in place from recording →
/// processing without dismissing, then auto-dismisses on `.completed` / `.failed`
/// so control returns to the calling Shortcut promptly. See PRD §5.5 and TDD §8.1.
///
/// Visual treatment is shared with `RootView` (PRD §5.8) so users transitioning
/// from "AppIntent sheet" to "open app from springboard" see the same surface.
@MainActor
struct RecordingSheet: View {
  let prompt: String?
  let onDismiss: () -> Void

  @State private var state: TranscriptionSession.State = .idle
  @State private var elapsed: TimeInterval = 0

  private var session: TranscriptionSession {
    AppEnvironment.shared.session
  }

  var body: some View {
    VStack(spacing: 24) {
      if let prompt, !prompt.isEmpty {
        Text(prompt)
          .font(.headline)
          .multilineTextAlignment(.center)
          .padding(.top, 24)
          .accessibilityAddTraits(.isHeader)
      }

      Spacer(minLength: 0)

      stateContent

      Spacer(minLength: 0)

      primaryControl
        .padding(.bottom, 24)
    }
    .padding(.horizontal, 24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.regularMaterial)
    .task(id: ObjectIdentifier(session)) {
      for await next in await session.stateStream {
        state = next
        if case let .recording(startedAt, _) = next {
          elapsed = Date().timeIntervalSince(startedAt)
        }
        if case .completed = next { onDismiss() }
        if case .failed = next { onDismiss() }
      }
    }
    .task(id: isRecording) {
      guard isRecording else { return }
      while !Task.isCancelled, case let .recording(startedAt, _) = state {
        elapsed = Date().timeIntervalSince(startedAt)
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private var stateContent: some View {
    switch state {
    case .idle:
      ProgressView()
    case let .recording(_, level):
      recordingContent(level: level)
    case let .processing(progress):
      processingContent(progress: progress)
    case .completed, .failed:
      ProgressView()
    }
  }

  private func recordingContent(level: Float) -> some View {
    VStack(spacing: 16) {
      Text(formattedElapsed)
        .font(.system(size: 48, weight: .semibold, design: .rounded).monospacedDigit())
        .foregroundStyle(elapsedColor)
        .accessibilityLabel(accessibleElapsed)
        .accessibilityValue(elapsedSeverityLabel)

      LevelMeter(level: displayLevel(rms: level))
        .frame(height: 12)
        .accessibilityHidden(true) // decorative; the "Recording" label conveys state

      Text("Recording")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.isStaticText)
    }
    .accessibilityElement(children: .combine)
  }

  private func processingContent(progress: TranscriptionProgress) -> some View {
    VStack(spacing: 16) {
      ProgressView()
        .controlSize(.large)
        .accessibilityHidden(true)
      Text(processingLabel(progress))
        .font(.headline)
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.updatesFrequently)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(processingLabel(progress))
  }

  private var primaryControl: some View {
    Button(action: stopTapped) {
      Text(buttonLabel)
        .font(.headline)
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .tint(isRecording ? .red : .accentColor)
    .disabled(isProcessing)
  }

  // MARK: - Helpers

  private var isRecording: Bool {
    if case .recording = state { return true }
    return false
  }

  private var isProcessing: Bool {
    if case .processing = state { return true }
    return false
  }

  private var buttonLabel: String {
    switch state {
    case .recording: "Stop"
    case .processing: "Transcribing…"
    case .idle, .completed, .failed: "—"
    }
  }

  private var formattedElapsed: String {
    let total = Int(elapsed)
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  /// Spoken form, e.g. "2 minutes 13 seconds". Avoids VoiceOver reading
  /// "0:13" as "zero colon one three" on the bare numeric counter.
  private var accessibleElapsed: String {
    let total = Int(elapsed)
    let minutes = total / 60
    let seconds = total % 60
    var parts: [String] = []
    if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
    parts.append("\(seconds) second\(seconds == 1 ? "" : "s")")
    return "Elapsed: " + parts.joined(separator: " ")
  }

  private var elapsedSeverityLabel: String {
    let fraction = elapsed / RecordingLimits.maxRecordingSeconds
    if fraction >= RecordingLimits.criticalThreshold { return "approaching maximum recording length" }
    if fraction >= RecordingLimits.warningThreshold { return "warning, nearing recording limit" }
    return ""
  }

  /// Color shifts at the cap-relative thresholds defined in `RecordingLimits`
  /// (TDD §7.3). Warning at 80%, critical at 95% — both follow the cap when S3 lands.
  private var elapsedColor: Color {
    let fraction = elapsed / RecordingLimits.maxRecordingSeconds
    if fraction >= RecordingLimits.criticalThreshold { return .red }
    if fraction >= RecordingLimits.warningThreshold { return .orange }
    return .primary
  }

  private func processingLabel(_ progress: TranscriptionProgress) -> String {
    switch progress {
    case .starting: "Starting transcription…"
    case .phase(.encoding): "Encoding…"
    case .phase(.decoding): "Transcribing…"
    case .finishing: "Finishing up…"
    }
  }

  /// Same dB-remap formula validated on device in M3 (`DebugRecordingView`).
  /// Maps `-60 dBFS → 0`, `0 dBFS → 1` so the meter responds across the range a
  /// human voice occupies rather than the bottom 20% of a linear plot.
  private func displayLevel(rms: Float) -> Double {
    let safeRMS = max(Double(rms), 1e-6)
    let dB = 20 * log10(safeRMS)
    let normalized = (dB + 60) / 60
    return min(1, max(0, normalized))
  }

  private func stopTapped() {
    Task { await session.stopRecording() }
  }
}

/// Simple horizontal level meter. Extracted so `RootView` can reuse it without
/// pulling in the whole sheet.
struct LevelMeter: View {
  let level: Double

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Capsule().fill(.quaternary)
        Capsule()
          .fill(.red)
          .frame(width: proxy.size.width * level)
      }
    }
  }
}
