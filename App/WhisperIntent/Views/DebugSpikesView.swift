import SwiftUI
import WhisperIntentCore

/// Spike harness screen for the M2 spikes. Remove (or re-gate) before TestFlight
/// in M6. Reachable from `RootView`. Logs are shown on screen and dumped to a
/// file under `Documents/` so they can be retrieved via Finder ("Devices and
/// Simulators → app → download container").
@MainActor
struct DebugSpikesView: View {
  @State private var events: [SpikeLogEvent] = []
  @State private var isRunning = false
  @State private var lastDumpPath: String?
  @State private var lastDumpURL: URL?

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        controls
        Divider()
        logList
      }
      .navigationTitle("Spike harness")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  @State private var showRecordingHarness = false

  private var controls: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("M3 — recording end-to-end").font(.headline)
      Button("Open recording harness") { showRecordingHarness = true }
        .disabled(isRunning)
        .sheet(isPresented: $showRecordingHarness) {
          DebugRecordingView()
        }

      Divider()

      Text("Spike S1 — progress callbacks").font(.headline)
      HStack {
        Button("Run 30s sample") { Task { await run(sample: "sample-30s") } }
          .disabled(isRunning)
        Button("Run 300s sample") { Task { await run(sample: "sample-300s") } }
          .disabled(isRunning)
        Spacer()
        if isRunning {
          ProgressView().controlSize(.small)
        }
      }
      HStack {
        Button("Clear log") {
          events.removeAll()
          lastDumpPath = nil
          lastDumpURL = nil
        }
        .disabled(events.isEmpty || isRunning)
        if let url = lastDumpURL {
          ShareLink(item: url) {
            Text("Share log")
          }
          .disabled(isRunning)
        }
        Spacer()
        if let path = lastDumpPath {
          Text("Dumped: \(path)")
            .font(.caption2)
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding()
  }

  private var logList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          ForEach(events) { event in
            Text(event.logLine)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(color(for: event.kind))
              .id(event.id)
          }
        }
        .padding(.horizontal)
      }
      .onChange(of: events.count) { _, _ in
        if let last = events.last { proxy.scrollTo(last.id, anchor: .bottom) }
      }
    }
  }

  // MARK: - Runner

  private func run(sample: String) async {
    isRunning = true
    events.removeAll()
    lastDumpPath = nil
    lastDumpURL = nil
    defer { isRunning = false }

    guard let audioURL = Bundle.main.url(forResource: sample, withExtension: "wav") else {
      events.append(SpikeLogEvent(
        kind: .harnessError,
        elapsed: 0,
        summary: "missing \(sample).wav in bundle"
      ))
      return
    }

    let appender: @Sendable (SpikeLogEvent) -> Void = { event in
      Task { @MainActor in
        events.append(event)
      }
    }

    let harness = SpikeS1Harness(observer: appender)
    await harness.run(audioURL: audioURL)

    // Small delay so any final observer hop completes before we dump.
    try? await Task.sleep(nanoseconds: 100_000_000)
    lastDumpURL = await dump(sample: sample)
    lastDumpPath = lastDumpURL?.path
  }

  private func dump(sample: String) async -> URL? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withColonSeparatorInTime]
    let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let name = "spike-s1-\(sample)-\(stamp).log"
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    guard let dest = docs?.appendingPathComponent(name) else { return nil }
    let body = events.map(\.logLine).joined(separator: "\n")
    do {
      try body.write(to: dest, atomically: true, encoding: .utf8)
      return dest
    } catch {
      events.append(SpikeLogEvent(
        kind: .harnessError,
        elapsed: 0,
        summary: "log write error: \(error)"
      ))
      return nil
    }
  }

  private func color(for kind: SpikeLogEvent.Kind) -> Color {
    switch kind {
    case .harnessStart, .transcribeStart, .modelLoadStart: .blue
    case .transcribeEnd, .modelLoadEnd: .green
    case .harnessError: .red
    case .progress: .primary
    case .segmentDiscovered: .purple
    case .modelState, .transcriptionState: .orange
    case .metrics: .teal
    }
  }
}

#Preview {
  DebugSpikesView()
}
