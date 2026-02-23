// Ultra-Aggressive Reproduction - Multiple Parallel Stress Tests
//
// This version tries multiple strategies to trigger the Speech framework crash:
// 1. Rapid parallel creation of multiple recognizers
// 2. Immediate query of bestAvailableAudioFormat from multiple threads
// 3. Immediate prepareToAnalyze calls
// 4. No audio engine complexity - just stress the Speech framework init

import Foundation
@preconcurrency import Speech
@preconcurrency import AVFoundation

@available(macOS 26.0, *)
actor UltraAggressiveSpeechRecognizer {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    var analyzerFormat: AVAudioFormat?

    let locale: Locale
    let identifier: String

    init(locale: Locale, identifier: String) {
        self.locale = locale
        self.identifier = identifier
    }

    // Most aggressive setup possible - everything immediate, no delays
    func setupUltraAggressive() async throws {
        print("[\(identifier)] START")

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

        // IMMEDIATE query - no delay
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        guard let analyzerFormat else {
            throw NSError(domain: "SetupError", code: 2)
        }

        // IMMEDIATE analyzer creation - no delay
        analyzer = SpeechAnalyzer(modules: [transcriber])

        // IMMEDIATE prepareToAnalyze - no delay
        try await analyzer?.prepareToAnalyze(in: analyzerFormat)

        print("[\(identifier)] COMPLETE")
    }
}

@available(macOS 26.0, *)
@main
struct UltraAggressiveReproApp {
    static func main() async {
        print("=== Ultra-Aggressive Speech Framework Crash Test ===")
        print("Strategy: Create many recognizers in parallel ASAP")
        print("")

        let useWorkaround = false

        // TEST 1: Two recognizers in parallel (original failure case)
        print("TEST 1: Two recognizers in parallel")
        do {
            let en = UltraAggressiveSpeechRecognizer(locale: Locale(identifier: "en-US"), identifier: "EN1")
            let fr = UltraAggressiveSpeechRecognizer(locale: Locale(identifier: "fr-FR"), identifier: "FR1")

            if useWorkaround {
                try await en.setupUltraAggressive()
                try await Task.sleep(for: .milliseconds(300))
                try await fr.setupUltraAggressive()
            } else {
                // PARALLEL - both setup simultaneously
                async let eng: () = en.setupUltraAggressive()
                async let fre: () = fr.setupUltraAggressive()
                _ = try await (eng, fre)
            }

            print("✅ Test 1 passed")
        } catch {
            print("❌ Test 1 failed: \(error)")
        }
        print("")

        // TEST 2: Four recognizers in parallel (more stress)
        print("TEST 2: Four recognizers in parallel")
        do {
            let en1 = UltraAggressiveSpeechRecognizer(locale: Locale(identifier: "en-US"), identifier: "EN2a")
            let fr1 = UltraAggressiveSpeechRecognizer(locale: Locale(identifier: "fr-FR"), identifier: "FR2a")
            let en2 = UltraAggressiveSpeechRecognizer(locale: Locale(identifier: "en-US"), identifier: "EN2b")
            let fr2 = UltraAggressiveSpeechRecognizer(locale: Locale(identifier: "fr-FR"), identifier: "FR2b")

            if useWorkaround {
                try await en1.setupUltraAggressive()
                try await Task.sleep(for: .milliseconds(300))
                try await fr1.setupUltraAggressive()
                try await Task.sleep(for: .milliseconds(300))
                try await en2.setupUltraAggressive()
                try await Task.sleep(for: .milliseconds(300))
                try await fr2.setupUltraAggressive()
            } else {
                // ALL FOUR PARALLEL
                async let a: () = en1.setupUltraAggressive()
                async let b: () = fr1.setupUltraAggressive()
                async let c: () = en2.setupUltraAggressive()
                async let d: () = fr2.setupUltraAggressive()
                _ = try await (a, b, c, d)
            }

            print("✅ Test 2 passed")
        } catch {
            print("❌ Test 2 failed: \(error)")
        }
        print("")

        // TEST 3: Rapid sequential creation (timing stress)
        print("TEST 3: Rapid sequential creation (10x)")
        do {
            for i in 1...10 {
                let recognizer = UltraAggressiveSpeechRecognizer(
                    locale: Locale(identifier: i % 2 == 0 ? "en-US" : "fr-FR"),
                    identifier: "T3-\(i)"
                )
                try await recognizer.setupUltraAggressive()

                if useWorkaround && i < 10 {
                    try await Task.sleep(for: .milliseconds(300))
                }
            }
            print("✅ Test 3 passed")
        } catch {
            print("❌ Test 3 failed: \(error)")
        }
        print("")

        print("=== All tests complete ===")
    }
}

/*
ULTRA-AGGRESSIVE STRATEGIES:

This version attempts to trigger the Speech framework crash through:

1. PARALLEL INITIALIZATION
   - Multiple recognizers created simultaneously
   - All calling bestAvailableAudioFormat in parallel
   - All calling prepareToAnalyze in parallel
   - Maximum stress on Speech framework XPC services

2. RAPID SEQUENTIAL CREATION
   - 10 recognizers created one after another
   - No delays between creations
   - Tests if the framework can handle rapid setup/teardown

3. MULTIPLE TEST CASES
   - Escalating complexity
   - Test 1: 2 parallel (baseline)
   - Test 2: 4 parallel (high stress)
   - Test 3: 10 sequential (rapid churn)

4. SIMPLIFIED CODE PATH
   - No audio engine
   - No audio tap
   - No actual audio processing
   - Just pure Speech framework initialization stress

EXPECTED CRASHES:

Without workaround delays, should crash at:
- bestAvailableAudioFormat when multiple recognizers query simultaneously
- prepareToAnalyze when multiple recognizers prepare simultaneously
- Swift metadata instantiation when creating multiple transcribers too fast
- XPC service initialization race conditions

This mirrors real-world scenarios where an application might:
- Support multiple languages
- Allow dynamic language switching
- Create/destroy recognizers frequently
- Initialize quickly at startup
*/
