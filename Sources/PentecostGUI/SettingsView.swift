import SwiftUI

@available(macOS 26.0, *)
struct SettingsView: View {
    @ObservedObject var viewModel: PentecostViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("⚙️ Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Translation Settings
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Translation Settings", systemImage: "globe")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Configure which language to translate into for each audio source")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 16) {
                            // Local (Microphone) Translation
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "mic.fill")
                                        .foregroundColor(.blue)
                                    Text("Local (Your Microphone)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                Text("Translate your speech into:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $viewModel.settings.localTranslationLanguage) {
                                    ForEach(TranslationLanguage.allCases) { lang in
                                        Text("\(lang.flag) \(lang.rawValue)")
                                            .tag(lang)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.05))
                            .cornerRadius(8)
                            
                            // Remote (System Audio) Translation
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.green)
                                    Text("Remote (System Audio)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                Text("Translate remote speech into:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $viewModel.settings.remoteTranslationLanguage) {
                                    ForEach(TranslationLanguage.allCases) { lang in
                                        Text("\(lang.flag) \(lang.rawValue)")
                                            .tag(lang)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: .infinity)
                            }
                            .padding()
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // Audio Device Settings (shown only when not running)
                    if !viewModel.isRunning {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Audio Devices", systemImage: "waveform")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Select audio input devices for transcription")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 16) {
                                // Local Device
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "mic.fill")
                                            .foregroundColor(.blue)
                                        Text("Local Device")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Picker("Local Device", selection: $viewModel.selectedLocalDeviceID) {
                                        ForEach(viewModel.availableDevices, id: \.deviceID) { device in
                                            Text("\(device.name) (\(device.inputChannels)ch)")
                                                .tag(Optional(device.deviceID))
                                        }
                                    }
                                    .labelsHidden()
                                }
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(8)
                                
                                // Remote Device
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundColor(.green)
                                        Text("Remote Device")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Picker("Remote Device", selection: $viewModel.selectedRemoteDeviceID) {
                                        ForEach(viewModel.availableDevices, id: \.deviceID) { device in
                                            Text("\(device.name) (\(device.inputChannels)ch)")
                                                .tag(Optional(device.deviceID))
                                        }
                                    }
                                    .labelsHidden()
                                }
                                .padding()
                                .background(Color.green.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    
                    // Info Section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("About", systemImage: "info.circle")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Pentecost v1.0")
                            .font(.subheadline)
                        
                        Text("Real-time multilingual speech recognition and translation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 600, height: 700)
    }
}
