// Minimal Reproduction Case for Speech Framework Initialization Bug
// macOS 26.0 Beta - SpeechAnalyzer/SpeechTranscriber crashes without delays
//
// ISSUE: Creating SpeechTranscriber and SpeechAnalyzer too quickly causes heap corruption
// CRASH LOCATION: malloc internals, XPC service initialization, Swift metadata instantiation
// WORKAROUND: Add artificial delays between object creation
//
// To reproduce:
// 1. Build in RELEASE mode: swift build -c release
// 2. Run the binary
// 3. Observe crashes in Speech framework internals

import Foundation
@preconcurrency import Speech

@available(macOS 26.0, *)
actor MinimalSpeechRecognizer {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?

    let locale: Locale

    init(locale: Locale) {
        self.locale = locale
    }

    // VERSION 1: WITHOUT DELAYS - CRASHES IN RELEASE BUILD
    func setupWithoutDelays() async throws {
        print("Setting up transcriber for \(locale.identifier)...")

        // Create transcriber - may crash here or shortly after
        transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        guard let transcriber else {
            throw NSError(domain: "SetupError", code: 1)
        }

        // Create input stream
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        // Get audio format - CRASHES HERE: bestAvailableAudioFormat queries uninitialized state
        let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        guard let audioFormat else {
            throw NSError(domain: "SetupError", code: 2)
        }

        // Create analyzer - CRASHES HERE: malloc corruption from premature initialization
        analyzer = SpeechAnalyzer(modules: [transcriber])

        // Prepare analyzer - CRASHES HERE: XPC service not ready, malloc corruption
        try await analyzer?.prepareToAnalyze(in: audioFormat)

        print("✅ Setup complete for \(locale.identifier)")
    }

    // VERSION 2: WITH DELAYS - WORKS (WORKAROUND)
    func setupWithDelays() async throws {
        print("Setting up transcriber for \(locale.identifier)...")

        // Create transcriber
        transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        guard let transcriber else {
            throw NSError(domain: "SetupError", code: 1)
        }

        // WORKAROUND: Wait for Speech framework internal initialization
        try await Task.sleep(for: .milliseconds(200))

        // Create input stream
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

        // Get audio format
        let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        guard let audioFormat else {
            throw NSError(domain: "SetupError", code: 2)
        }

        // Create analyzer
        analyzer = SpeechAnalyzer(modules: [transcriber])

        // WORKAROUND: Wait before prepareToAnalyze() to avoid malloc crash
        try await Task.sleep(for: .milliseconds(100))

        // Prepare analyzer
        try await analyzer?.prepareToAnalyze(in: audioFormat)

        print("✅ Setup complete for \(locale.identifier)")
    }
}

@available(macOS 26.0, *)
@main
struct MinimalReproApp {
    static func main() async {
        print("=== Speech Framework Initialization Bug Demo ===")
        print("Build: swift build -c release")
        print("")

        // Test with multiple recognizers to show the issue more clearly
        // Creating second recognizer often crashes without delays
        do {
            print("Creating first recognizer (English)...")
            let english = MinimalSpeechRecognizer(locale: Locale(identifier: "en-US"))

            // CHANGE THIS FLAG TO TEST:
            let useWorkaround = true  // Set to false to reproduce crash

            if useWorkaround {
                try await english.setupWithDelays()
                print("Waiting 300ms before second recognizer...")
                try await Task.sleep(for: .milliseconds(300))
            } else {
                try await english.setupWithoutDelays()
                // No delay - will likely crash on second recognizer
            }

            print("\nCreating second recognizer (French)...")
            let french = MinimalSpeechRecognizer(locale: Locale(identifier: "fr-FR"))

            if useWorkaround {
                try await french.setupWithDelays()
            } else {
                try await french.setupWithoutDelays()
            }

            print("\n✅ Both recognizers initialized successfully")
            print("(With workaround delays: \(useWorkaround))")

        } catch {
            print("❌ Setup failed: \(error)")
        }
    }
}

/*
EXPECTED BEHAVIOR:
- Should be able to create SpeechTranscriber and SpeechAnalyzer immediately
- Speech framework should handle internal initialization synchronously or safely
- No crashes in malloc, XPC, or metadata instantiation

ACTUAL BEHAVIOR (Release build without delays):
- Heap corruption crashes: "BUG IN CLIENT OF LIBMALLOC: memory corruption of free block"
- XPC service crashes during Speech framework internal initialization
- Swift metadata instantiation crashes
- Crashes occur at:
  1. bestAvailableAudioFormat() - queries uninitialized state
  2. SpeechAnalyzer() constructor - premature initialization
  3. prepareToAnalyze() - XPC service not ready

CRASH LOCATIONS:
- malloc_zone_malloc
- Swift._convertConstStringToUTF8PointerImpl
- type metadata instantiation
- Various Speech framework internal functions

WORKAROUND:
- Add 200ms delay after SpeechTranscriber creation
- Add 100ms delay before prepareToAnalyze()
- Add 300ms delay between creating multiple recognizers
- Total: ~400ms per recognizer + 300ms between recognizers

IMPACT:
- Applications requiring multiple language recognizers need 1+ seconds of artificial delays
- Poor user experience (slow startup)
- No documentation suggests delays are needed
- Apple's sample code has NO delays
- Bug only appears in Release builds (optimization-related?)
*/
