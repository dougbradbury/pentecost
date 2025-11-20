import SwiftUI
import Speech
import AVFoundation

@available(macOS 26.0, *)
@main
struct PentecostApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 700)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

@available(macOS 26.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request permissions on app launch
        Task {
            await requestPermissions()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func requestPermissions() async {
        // Request speech recognition permission
        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        if speechAuth != .authorized {
            print("❌ Speech recognition not authorized: \(speechAuth.rawValue)")
        }

        // Request microphone permission
        let micPermission = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        if !micPermission {
            print("❌ Microphone permission denied")
        }
    }
}
