# 🚀 Pentecost Quick Start

## First Time Setup (5 minutes)

### 1. Build the App
```bash
./build.sh
```

### 2. Grant Permissions
When Pentecost launches, you'll see two permission dialogs:
- **Speech Recognition** → Click "OK"
- **Microphone** → Click "Allow"

### 3. Start Transcribing
- Click the **Start** button
- Speak into your microphone
- Watch live transcriptions appear in the left column (🎤 LOCAL)

**That's it! You're ready to go.**

---

## For Video Call Transcription

Want to transcribe Zoom/Meet calls? Install BlackHole:

```bash
brew install blackhole-2ch
```

### Configure Audio Routing

1. **Open Audio MIDI Setup** (Cmd+Space → type "Audio MIDI")
2. **Click "+" → Create Multi-Output Device**
3. **Check both:**
   - Your speakers/headphones
   - BlackHole 2ch
4. **Set as system output:** System Settings → Sound → Output → Multi-Output Device
5. **In Pentecost:** Select BlackHole as remote input

Now both your voice AND the call audio will be transcribed!

---

## Tips

- 📝 **Logs are automatic** - Click "Open Logs" to find them
- 🎯 **Language detection is automatic** - Just speak, it figures it out
- 🛑 **Click Stop** when you're done to save the session
- 🔄 **Rebuild anytime** with `./build.sh`

## Troubleshooting

**App won't open?**
```bash
rm -rf Pentecost.app && ./build.sh
```

**No permission dialogs?**
```bash
tccutil reset Microphone && tccutil reset SpeechRecognition
./build.sh
```

**Need help?** Check `README.md` for full documentation.
