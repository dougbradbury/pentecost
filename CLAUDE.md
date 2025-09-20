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

## Development Roadmap: Advanced Meeting Transcription System

The project is evolving from a basic multilingual speech recognizer into a comprehensive meeting transcription and translation system.

### Phase 1: Translation & Real-time Features
1. **Real-time translation** - Translate transcribed text between English ↔ French as it's recognized
2. **Live transcript saving** - Append each finalized line to meeting transcript file with timestamps
3. **Translation API research** - Investigate Apple Translation API or integrate third-party translation service

### Phase 2: Audio Management
4. **Audio channel selection** - Build UI for choosing input sources (microphone, system audio, etc.)
5. **Local mic recording** - Save microphone input to audio file during meetings
6. **System audio capture** - Record remote participant audio output channel for complete meeting archive

### Phase 3: Session & Output Management
7. **Meeting session controls** - Add start/stop/pause functionality for recording & transcription
8. **Transcript file format** - Implement structured format with timestamps, speaker identification, and language detection
9. **Meeting summary generator** - Create AI-powered content summarization from transcribed content
10. **Bilingual summaries** - Generate meeting summaries in both English and French

### Technical Implementation Notes
- Current foundation: Parallel English/French recognition with terminal overwriting and timing display
- Centralized output formatting via pure static function for easy extension
- Git repository initialized with proper .gitignore for Swift projects

## Previous Future Considerations (Completed/Superseded)
- ✅ Add confidence scoring display - superseded by translation focus
- 🔄 Implement audio input device selection - moved to Phase 2
- 🔄 Add recording capabilities - expanded in Phase 2
- ✅ Consider expanding to additional languages - focusing on EN/FR translation first
- 🔄 Add UI interface beyond console output - deferred for audio management priority

## Reference Documentation

- Apple's SpeechAnalyzer API: https://developer.apple.com/documentation/speech/speechanalyzer
- Example project studied: BringingAdvancedSpeechToTextCapabilitiesToYourApp
- Key insight: SpeechTranscriber constructor simplified compared to documentation assumptions

This project represents a successful implementation of Apple's cutting-edge multilingual speech recognition capabilities in a clean, focused application.