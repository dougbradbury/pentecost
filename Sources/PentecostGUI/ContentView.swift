import SwiftUI

@available(macOS 26.0, *)
struct ContentView: View {
    @StateObject private var viewModel = PentecostViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()

            Divider()

            // Status bar
            StatusBarView(status: viewModel.statusMessage, isRunning: viewModel.isRunning)

            Divider()

            // Main content - two column layout
            HStack(spacing: 0) {
                // Left column - Local (Microphone)
                TranscriptionColumn(
                    title: "🎤 LOCAL (You)",
                    messages: viewModel.localMessages,
                    color: .blue
                )

                Divider()

                // Right column - Remote (System Audio)
                TranscriptionColumn(
                    title: "🔊 REMOTE (Them)",
                    messages: viewModel.remoteMessages,
                    color: .green
                )
            }

            Divider()

            // Control buttons
            ControlsView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@available(macOS 26.0, *)
struct HeaderView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("🕊️ PENTECOST")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text("Real-time Multilingual Speech Recognition & Translation")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("English ⟷ French")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

@available(macOS 26.0, *)
struct StatusBarView: View {
    let status: String
    let isRunning: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(status)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

@available(macOS 26.0, *)
struct TranscriptionColumn: View {
    let title: String
    let messages: [TranscriptionMessage]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            Text(title)
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.1))

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            MessageView(message: message, accentColor: color)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@available(macOS 26.0, *)
struct MessageView: View {
    let message: TranscriptionMessage
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Language and timestamp
            HStack {
                Image(systemName: message.isEnglish ? "flag.fill" : "flag.fill")
                    .foregroundColor(message.isEnglish ? .blue : .purple)

                Text(message.isEnglish ? "English" : "Français")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Original text
            Text(message.text)
                .font(.body)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(accentColor.opacity(0.05))
                .cornerRadius(6)

            // Translation if available
            if let translation = message.translation {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(translation)
                        .font(.body)
                        .italic()
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(6)
            }
        }
    }
}

@available(macOS 26.0, *)
struct ControlsView: View {
    @ObservedObject var viewModel: PentecostViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Device info bar
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "🎤")
                        .foregroundColor(.blue)
                    Text("Local:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.selectedLocalDevice)
                        .font(.caption)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "🔊")
                        .foregroundColor(.green)
                    Text("Remote:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(viewModel.selectedRemoteDevice)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Control buttons
            HStack(spacing: 16) {
                if !viewModel.isRunning {
                    Button(action: {
                        Task {
                            await viewModel.start()
                        }
                    }) {
                        Label("Start", systemImage: "play.fill")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(action: {
                        Task {
                            await viewModel.stop()
                        }
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button(action: {
                    viewModel.clearTranscripts()
                }) {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(viewModel.localMessages.isEmpty && viewModel.remoteMessages.isEmpty)

                Spacer()

                Button(action: {
                    viewModel.openLogsFolder()
                }) {
                    Label("Open Logs", systemImage: "folder")
                }
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}
