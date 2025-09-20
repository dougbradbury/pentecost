# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this project.

## Project Overview

This is a real-time multilingual speech recognition application built with Apple's new SpeechAnalyzer API (requires macOS 26.0+). The project demonstrates parallel speech recognition for English and French with automatic language detection.

## Project History

This project was extracted from a larger meeting-recorder project after successfully implementing the core multilingual recognition functionality. We went through several iterations to arrive at the current clean implementation:

1. **Initial Research**: Discovered Apple's SpeechAnalyzer API and studied the official example project "BringingAdvancedSpeechToTextCapabilitiesToYourApp"
2. **API Discovery**: Found that SpeechTranscriber requires NO preset parameter (contrary to initial assumptions)
3. **Multiple Attempts**: Built and discarded several implementations (EnglishRecognizer, FrenchRecognizer, SpeechAnalyzerDemo, TranslatorEngine)
4. **Final Success**: Created ProductionMultilingualRecognizer that runs parallel recognition streams
5. **Cleanup**: Removed all failed attempts and moved to dedicated project directory

## Current Implementation

### Key Features
- **Parallel Recognition**: Runs English (en-US) and French (fr-FR) speech recognition simultaneously
- **Automatic Language Detection**: Uses SpeechAnalyzer with multiple transcribers for smart routing
- **Clean Output**: Extracts plain text from AttributedString results to avoid metadata noise
- **Real-time Processing**: Displays both partial and final recognition results
- **Audio Format Conversion**: Handles audio format compatibility between input and transcribers

### Architecture
- `ProductionMultilingualRecognizer`: Main class orchestrating dual-language recognition
- `BufferConverter`: Handles audio format conversion for transcriber compatibility
- Parallel Task execution for processing results from both language transcribers
- AsyncStream for audio input management

## Key Technical Discoveries

### Correct SpeechTranscriber Usage
```swift
// NO preset parameter needed - this was the key discovery
englishTranscriber = SpeechTranscriber(
    locale: Locale(identifier: "en-US"),
    transcriptionOptions: [],
    reportingOptions: [.volatileResults],
    attributeOptions: [.audioTimeRange]
)
```

### Result Processing Pattern
```swift
// Process results inline to avoid type annotation issues
let englishTask = Task {
    for try await case let result in englishTranscriber.results {
        let text = String(result.text.characters) // Extract clean text
        if result.isFinal {
            print("✅ 🇺🇸 FINAL: \(text)")
        } else {
            print("⏳ 🇺🇸 PARTIAL: \(text)")
        }
    }
}
```

### SpeechAnalyzer Setup
```swift
// Create analyzer with multiple transcribers for automatic language detection
analyzer = SpeechAnalyzer(modules: [englishTranscriber, frenchTranscriber])

// Get optimal audio format compatible with both transcribers
analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
    compatibleWith: [englishTranscriber, frenchTranscriber]
)
```

## Current Goals

1. **Working Parallel Recognition**: ✅ COMPLETED
   - Both English and French transcribers run simultaneously
   - Display separate output streams with language flags (🇺🇸/🇫🇷)
   - Show both partial and final results

2. **Clean Output Format**: ✅ COMPLETED
   - Extract plain text from AttributedString to avoid metadata noise
   - Clear visual distinction between languages and result types

3. **No Language Switching Logic**: ✅ COMPLETED
   - Deliberately kept simple - just show parallel streams
   - No automatic switching or confidence-based selection
   - User can see both recognition streams simultaneously

## Development Commands

```bash
# Build the project
swift build

# Run the recognizer
./.build/debug/MultilingualRecognizer

# Clean build (if needed)
rm -rf .build && swift build
```

## Known Issues Fixed

1. **Build Cache Problems**: Fixed by cleaning .build directory when moving projects
2. **Type Annotation Errors**: Fixed by letting Swift infer types from transcriber.results
3. **AttributedString Output**: Fixed by extracting plain text with String(result.text.characters)
4. **Sendable Warning**: Present but non-blocking - ProductionMultilingualRecognizer capture warning

## File Structure

```
RealTimeTranslatorApp/
├── Package.swift                          # Swift package configuration
├── Sources/MultilingualRecognizer/
│   └── main.swift                         # Complete implementation
└── docs/
    └── SpeechAnalyzer _ Apple Developer Documentation.html
```

## Future Considerations

- Add confidence scoring display if needed
- Implement audio input device selection
- Add recording capabilities
- Consider expanding to additional languages
- Add UI interface beyond console output

## Reference Documentation

- Apple's SpeechAnalyzer API: https://developer.apple.com/documentation/speech/speechanalyzer
- Example project studied: BringingAdvancedSpeechToTextCapabilitiesToYourApp
- Key insight: SpeechTranscriber constructor simplified compared to documentation assumptions

This project represents a successful implementation of Apple's cutting-edge multilingual speech recognition capabilities in a clean, focused application.