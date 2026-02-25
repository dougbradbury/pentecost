# Pentecost

*Real-time multilingual speech recognition and translation - where everyone understands everyone else*

Pentecost is a real-time speech recognition and translation application that captures dual audio streams (microphone + system audio), transcribes speech in English and French simultaneously, and provides live translations. Named after the biblical Pentecost where people of different languages could miraculously understand each other.

## Features

- **🎤 Dual Audio Capture**: Simultaneously records from microphone (local speech) and system audio (remote participants)
- **🌍 Multilingual Recognition**: Real-time speech recognition for English and French
- **⚡ Live Translation**: Instant translation between English ↔ French
- **📊 Two-Column Display**: Side-by-side English and French transcription with timestamps
- **📝 Meeting Transcripts**: Automatic transcript saving with weekly organization
- **🪝 Extensible Hooks**: Run custom commands when transcripts end (e.g., AI summarization)
- **🎛️ Dynamic Terminal**: Responsive interface that adapts to any terminal size
- **🔊 Device Selection**: Interactive audio device selection for optimal setup

## Requirements

- **macOS 26.0+** (requires Apple's new SpeechAnalyzer API)
- **Microphone permissions** for speech input
- **Audio input device** (USB headset, aggregate device, or BlackHole for system audio)

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd RealTimeTranslatorApp

# Build the application
swift build

# Run Pentecost
./.build/debug/MultilingualRecognizer
```

## Usage

1. **Launch the application** - You'll be prompted to select audio input devices
2. **Choose LOCAL device** - Your microphone for capturing your speech
3. **Choose REMOTE device** - System audio capture (use BlackHole or aggregate device for remote participants)
4. **Start speaking** - The app will transcribe and translate in real-time
5. **View results** - English and French appear in side-by-side columns with live translation
6. **Press Ctrl+N** - Start a new transcript (triggers hooks for previous transcript)
7. **Press Ctrl+C** - Shutdown (triggers hooks for final transcript)

### Keyboard Shortcuts

- **Ctrl+N**: Start new transcript file (clears display, runs hooks on previous transcript)
- **Ctrl+C**: Graceful shutdown (runs hooks, saves transcripts)

## Hooks System

Pentecost includes a flexible hook system to run custom commands when transcripts end. Perfect for:
- **AI Summarization**: Automatically summarize meetings with Claude or other AI
- **Backup**: Copy transcripts to cloud storage
- **Notifications**: Alert when meetings end
- **Custom Processing**: Run any command with transcript data

**Quick Setup**:
```bash
# Copy example configuration
cp hooks.yaml.example ~/.pentecost/hooks.yaml

# Edit and enable hooks you want
nano ~/.pentecost/hooks.yaml
```

See [HOOKS.md](HOOKS.md) for complete documentation and examples.

## Audio Setup

For complete meeting capture, install [BlackHole](https://github.com/ExistentialAudio/BlackHole) to capture system audio:

```bash
# Install BlackHole via Homebrew
brew install blackhole-2ch
```

Then configure your audio settings to route meeting audio through BlackHole while using your microphone for local speech.

## File Organization

Transcripts are automatically saved to:
```
~/Meeting_Recordings/summaries/Week_YYYY-MM-DD/transcripts/
├── transcript_2024-01-15_14-30-22_en-US.txt
└── transcript_2024-01-15_14-30-22_fr-FR.txt
```

Set custom location with: `export MEETING_SUMMARY_DIR=/path/to/your/summaries`

## Architecture

- **SingleLanguageSpeechRecognizer**: Handles individual language transcription using Apple's SpeechAnalyzer
- **BroadcastProcessor**: Enables parallel processing for terminal display + file saving
- **MessageBuffer**: Manages message deduplication and overlap handling
- **TerminalRenderer**: Dynamic terminal display with automatic sizing
- **TranscriptFileProcessor**: Saves final transcripts with weekly organization

## Development

```bash
# Run tests
swift test

# Clean build
rm -rf .build && swift build

# Development with verbose output
./.build/debug/MultilingualRecognizer --verbose
```

## Technical Notes

This application leverages Apple's cutting-edge SpeechAnalyzer API introduced in macOS 26.0, which provides:
- Superior multilingual speech recognition
- Real-time processing capabilities
- Advanced audio format compatibility
- Parallel transcriber support

## Contributing

Contributions welcome! This project demonstrates practical implementation of Apple's latest speech recognition technologies for real-world multilingual communication scenarios.

## License

MIT License - See LICENSE file for details

---

*"And they were all filled with the Holy Spirit and began to speak in other tongues as the Spirit enabled them... each one heard their own language being spoken."* - Acts 2:4,6