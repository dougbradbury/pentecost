# 🕊️ Pentecost

> "Where Everyone Understands Everyone Else"

Real-time multilingual speech recognition for macOS. Simultaneously transcribe audio from your microphone and system audio (e.g., video calls) with automatic language detection for English and French.

## ✨ Features

- **Dual Audio Capture**: Monitor local (microphone) and remote (system audio) simultaneously
- **Real-time Transcription**: Powered by Apple's Speech framework
- **Bilingual Support**: Automatic detection for English ⟷ French
- **Beautiful GUI**: Clean two-column SwiftUI interface
- **Automatic Logging**: All transcriptions saved to timestamped log files
- **Translation Ready**: Architecture supports real-time translation

## 🚀 Quick Start

### Requirements

- macOS 15.0 or later
- Xcode Command Line Tools
- Swift 6.1+

### Build & Run

```bash
./build.sh
```

The app will automatically open after building. On first launch, grant **Speech Recognition** and **Microphone** permissions when prompted.

## 📖 Usage

### Basic Operation

1. Launch `Pentecost.app` (double-click or `open Pentecost.app`)
2. Click **Start** to begin transcription
3. Speak or play audio
4. View real-time transcriptions:
   - **🎤 LOCAL (You)**: Your microphone
   - **🔊 REMOTE (Them)**: System audio
5. Click **Stop** to end the session
6. Click **Open Logs** to view saved transcriptions

### Capturing System Audio (Video Calls)

To capture audio from Zoom, Google Meet, etc., install a virtual audio device:

**BlackHole (Free, Recommended):**
```bash
brew install blackhole-2ch
```

Then configure:
1. Open **Audio MIDI Setup** (/Applications/Utilities/)
2. Create a **Multi-Output Device** with BlackHole + your speakers
3. Set as system output in System Settings → Sound
4. In Pentecost, select BlackHole as the remote input device

## 🏗️ Project Structure

```
Pentecost/
├── Pentecost.app              # Main GUI application
├── build.sh                   # Build script
├── Pentecost.entitlements     # Security permissions
├── logs/                      # Auto-generated transcription logs
└── Sources/
    ├── PentecostGUI/          # SwiftUI application
    └── MultilingualRecognizer/ # Core library (PentecostCore)
```

## 🔧 Development

### Building

```bash
# Build and create app bundle
./build.sh

# Build without bundling
swift build --product PentecostGUI

# Clean build
swift package clean
```

### Architecture

- **PentecostCore**: Audio processing, speech recognition, device management
- **PentecostGUI**: SwiftUI interface and user interaction
- **MVVM Pattern**: ViewModel coordinates recognition engines with UI
- **Protocol-based**: Dependency injection for testability

## 🐛 Troubleshooting

### App Won't Launch
- Verify macOS 15.0+
- Rebuild: `./build.sh`
- Check Console.app for errors

### No Permission Dialogs
```bash
# Reset permissions
tccutil reset Microphone
tccutil reset SpeechRecognition

# Rebuild
rm -rf Pentecost.app && ./build.sh
```

### Audio Not Captured
- Check System Settings → Sound
- For system audio: ensure virtual device is configured
- Click "Start" after granting permissions

## 📝 Logs

Logs are saved to: `logs/pentecost_YYYY-MM-DD_HH-MM-SS.log`

Click **"Open Logs"** in the app to access them.

## 🔐 Privacy

- All processing is **local** on your Mac
- No data sent to external servers
- Requires microphone and speech recognition permissions

## 🛠️ Tech Stack

- Swift 6.1 + SwiftUI
- AVFoundation (audio capture)
- Speech framework (transcription)
- CoreAudio (device management)
- Swift Concurrency (async/await)

## 🗺️ Roadmap

- [ ] Real-time translation English ⟷ French
- [ ] Additional languages
- [ ] Export to various formats
- [ ] Keyword search and highlighting
- [ ] Custom vocabulary
- [ ] Audio enhancement

## 📄 License

© 2025 MyAgro

---

*"And they were all filled with the Holy Spirit and began to speak in other tongues... each one heard their own language being spoken."* - Acts 2:4,6
