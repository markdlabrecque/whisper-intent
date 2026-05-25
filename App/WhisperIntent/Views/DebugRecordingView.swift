#if DEBUG
  import SwiftUI
  import WhisperIntentCore

  /// M3 exit-criterion harness: exercises `AppEnvironment.shared.session`
  /// end-to-end (mic permission → record → VAD or user-stop → WhisperKit → final
  /// transcript) so the core domain can be verified on a real device before any
  /// production UI lands in M5.
  ///
  /// Reachable from `DebugSpikesView`. Remove (or re-gate) before TestFlight in
  /// M6 along with the rest of the spike harnesses.
  @MainActor
  struct DebugRecordingView: View {
    @State private var state: TranscriptionSession.State = .idle
    @State private var permissionStatus: PermissionsService.MicrophoneStatus = .undetermined
    @State private var isBusy = false
    @State private var lastError: String?

    private var session: TranscriptionSession {
      AppEnvironment.shared.session
    }

    private var permissions: PermissionsService {
      AppEnvironment.shared.permissions
    }

    var body: some View {
      NavigationStack {
        VStack(spacing: 24) {
          statusBlock
          levelBlock
          transcriptBlock
          primaryButton
          if let error = lastError {
            Text(error)
              .font(.footnote)
              .foregroundStyle(.red)
              .multilineTextAlignment(.center)
          }
          Spacer()
        }
        .padding()
        .navigationTitle("Recording harness")
        .navigationBarTitleDisplayMode(.inline)
        .task {
          permissionStatus = permissions.microphoneStatus()
          for await next in await session.stateStream {
            state = next
          }
        }
      }
    }

    // MARK: - Subviews

    private var statusBlock: some View {
      VStack(spacing: 4) {
        Text("State")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(stateLabel)
          .font(.title2.monospaced())
        Text("Mic permission: \(String(describing: permissionStatus))")
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
      }
    }

    private var levelBlock: some View {
      VStack(spacing: 4) {
        Group {
          if case let .recording(_, level) = state {
            ProgressView(value: displayLevel(rms: level))
              .progressViewStyle(.linear)
              .tint(.red)
          } else {
            ProgressView(value: 0)
              .progressViewStyle(.linear)
              .tint(.secondary)
          }
        }
        Text(currentLevelText)
          .font(.caption2.monospaced())
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)
    }

    private var currentLevelText: String {
      if case let .recording(_, level) = state {
        let display = displayLevel(rms: level)
        return String(format: "rms: %.4f  bar: %.2f", level, display)
      }
      return "level: —"
    }

    /// Maps linear RMS amplitude to a 0...1 bar value using a dB scale so the
    /// meter responds across the range a human voice actually occupies (~-40
    /// dBFS quiet to ~-10 dBFS loud), not just the bottom 20% of the bar that a
    /// raw linear plot of RMS would show.
    private func displayLevel(rms: Float) -> Double {
      let safeRMS = max(Double(rms), 1e-6)
      let dB = 20 * log10(safeRMS)
      let normalized = (dB + 60) / 60 // -60 dBFS → 0, 0 dBFS → 1
      return min(1, max(0, normalized))
    }

    private var transcriptBlock: some View {
      Group {
        if case let .completed(transcript) = state {
          ScrollView {
            Text(transcript.isEmpty ? "(empty transcript)" : transcript)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(8)
              .background(.thinMaterial)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .frame(maxHeight: 200)
        }
      }
    }

    private var primaryButton: some View {
      Button(action: handleTap) {
        Text(buttonLabel)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(isBusy)
    }

    // MARK: - Labels

    private var stateLabel: String {
      switch state {
      case .idle: "idle"
      case .recording: "recording"
      case let .processing(progress): "processing(\(progress))"
      case .completed: "completed"
      case let .failed(error): "failed(\(error))"
      }
    }

    private var buttonLabel: String {
      switch state {
      case .idle, .completed, .failed: "Start recording"
      case .recording: "Stop"
      case .processing: "Transcribing…"
      }
    }

    // MARK: - Actions

    private func handleTap() {
      isBusy = true
      lastError = nil
      Task {
        defer { Task { @MainActor in isBusy = false } }
        switch state {
        case .idle, .completed, .failed:
          await startRecording()
        case .recording:
          await session.stopRecording()
        case .processing:
          break
        }
      }
    }

    private func startRecording() async {
      if case .completed = state {
        await session.reset()
      } else if case .failed = state {
        await session.reset()
      }

      permissionStatus = await permissions.requestMicrophone()
      guard permissionStatus == .granted else {
        lastError = "Microphone permission not granted (\(permissionStatus))."
        return
      }

      let config = RecordingConfig(
        silenceThreshold: 0,
        maxDuration: RecordingLimits.maxRecordingSeconds
      )
      do {
        try await session.startRecording(config: config)
      } catch {
        lastError = "startRecording failed: \(error)"
      }
    }
  }

  #Preview {
    DebugRecordingView()
  }
#endif
