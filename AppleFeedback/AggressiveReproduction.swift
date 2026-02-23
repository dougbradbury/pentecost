// More Aggressive Reproduction - With Audio Processing
// This version actually streams audio data and creates recognizers in parallel
//
// Key differences from MinimalReproduction.swift:
// 1. Creates recognizers in PARALLEL (not sequential)
// 2. Actually creates audio engine and tap
// 3. Streams real audio buffers through analyzers
// 4. Puts load on Speech framework XPC services

import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

@available(macOS 26.0, *)
actor AggressiveSpeechRecognizer {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognitionTask: Task<(), Never>?
    private var analysisTask: Task<(), Never>?

    let locale: Locale
    let identifier: String

    init(locale: Locale, identifier: String) {
        self.locale = locale
        self.identifier = identifier
    }

    // Aggressive setup - no delays, immediate usage
    func setupAggressive() async throws {
        print("[\(identifier)] Creating transcriber...")

        transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        guard let transcriber else {
            throw NSError(domain: "SetupError", code: 1)
        }

        // NO DELAY - immediate query
        print("[\(identifier)] Querying audio format...")
        let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        guard let audioFormat else {
            throw NSError(domain: "SetupError", code: 2)
        }

        // Create input stream
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        guard let inputSequence else {
            throw NSError(domain: "SetupError", code: 3)
        }

        // NO DELAY - immediate analyzer creation
        print("[\(identifier)] Creating analyzer...")
        analyzer = SpeechAnalyzer(modules: [transcriber])

        // Start recognition task IMMEDIATELY
        recognitionTask = Task {
            do {
                for try await case let result in transcriber.results {
                    print("[\(identifier)] Result: \(String(result.text.characters))")
                }
            } catch {
                print("[\(identifier)] Recognition error: \(error)")
            }
        }

        // NO DELAY - immediate prepareToAnalyze
        print("[\(identifier)] Calling prepareToAnalyze...")
        try await analyzer?.prepareToAnalyze(in: audioFormat)

        // Start analysis IMMEDIATELY
        analysisTask = Task {
            do {
                let lastTime = try await analyzer?.analyzeSequence(inputSequence)
                print("[\(identifier)] Analysis complete: \(lastTime?.seconds ?? 0)")
            } catch {
                print("[\(identifier)] Analysis error: \(error)")
            }
        }

        print("[\(identifier)] Setup complete!")
    }

    // Stream audio buffers to trigger actual processing
    func streamAudio(_ buffer: AVAudioPCMBuffer) async {
        let input = AnalyzerInput(buffer: buffer)
        inputBuilder?.yield(input)
    }

    func finish() async {
        inputBuilder?.finish()
        recognitionTask?.cancel()
        analysisTask?.cancel()
    }
}

@available(macOS 26.0, *)
@main
struct AggressiveReproApp {
    static func main() async {
        print("=== Aggressive Speech Framework Crash Reproduction ===")
        print("This version creates recognizers in PARALLEL and streams audio")
        print("")

        let useWorkaround = false  // Set to true to add delays

        do {
            // Create audio engine to get real audio buffers
            let audioEngine = AVAudioEngine()
            let inputNode = audioEngine.inputNode
            let bus = 0
            let inputFormat = inputNode.outputFormat(forBus: bus)

            print("Audio format: \(inputFormat)")
            print("")

            // Create recognizers IN PARALLEL (this is more likely to trigger race)
            print("Creating recognizers in PARALLEL...")

            // Create both recognizers simultaneously without waiting
            let english = AggressiveSpeechRecognizer(
                locale: Locale(identifier: "en-US"),
                identifier: "EN"
            )
            let french = AggressiveSpeechRecognizer(
                locale: Locale(identifier: "fr-FR"),
                identifier: "FR"
            )

            if useWorkaround {
                // Sequential with delays
                try await english.setupAggressive()
                try await Task.sleep(for: .milliseconds(300))
                try await french.setupAggressive()
            } else {
                // PARALLEL - both setup at the same time
                async let eng: () = english.setupAggressive()
                async let fr: () = french.setupAggressive()
                _ = try await (eng, fr)
            }

            print("")
            print("✅ Both recognizers created in parallel!")
            print("")

            // Now install audio tap and stream some data
            print("Installing audio tap...")
            inputNode.installTap(onBus: bus, bufferSize: 4096, format: inputFormat) { buffer, time in
                Task {
                    await english.streamAudio(buffer)
                    await french.streamAudio(buffer)
                }
            }

            // Start the engine
            print("Starting audio engine...")
            try audioEngine.start()
            print("✅ Audio engine started - streaming audio to both recognizers")
            print("")

            // Run for 2 seconds, streaming real audio
            print("Streaming audio for 2 seconds...")
            try await Task.sleep(for: .seconds(2))

            // Clean up
            print("Stopping...")
            audioEngine.stop()
            inputNode.removeTap(onBus: bus)
            await english.finish()
            await french.finish()

            print("✅ Test complete without crash!")

        } catch {
            print("❌ Error: \(error)")
        }
    }
}

/*
REPRODUCTION STRATEGY:

This version is more aggressive than MinimalReproduction.swift:

1. PARALLEL CREATION
   - Uses async let to create both recognizers simultaneously
   - This puts immediate parallel load on Speech framework
   - More likely to trigger XPC service race conditions

2. NO DELAYS
   - Calls bestAvailableAudioFormat immediately after transcriber creation
   - Calls prepareToAnalyze immediately after analyzer creation
   - No delay between recognizer creations

3. ACTUAL AUDIO PROCESSING
   - Creates real AVAudioEngine
   - Installs tap on microphone input
   - Streams real audio buffers to both analyzers
   - Recognition tasks are actually processing results

4. IMMEDIATE USAGE
   - Starts recognition and analysis tasks immediately
   - Buffers start flowing right away
   - Speech framework XPC services under real load

EXPECTED CRASH POINTS:

Without delays, crashes most likely at:
- bestAvailableAudioFormat (queries uninitialized state)
- prepareToAnalyze (XPC service not ready)
- When parallel recognizers both try to initialize XPC simultaneously

This mirrors the real application more closely:
- Parallel language processing
- Real audio streaming
- Active recognition tasks
- System resources under load
*/
