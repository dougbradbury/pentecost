# Speech Framework Crash Investigation - RESOLVED 2026-01-07

## Final Status: ✅ FIXED
The crashes were caused by incorrect usage of the SpeechAnalyzer API. Fixed by following Apple's documented patterns correctly.

## Environment
- **Current OS**: macOS 26.2 (build 25C56) - UPDATED from 26.1
- **Last Stable Commit**: `7b76679` - "Optimize startup delays while maintaining audio system stability"
- **Branch**: main
- **Stash**: Changes for local/remote speaker identification stashed (see below)

## Crash Pattern Evolution

### Phase 1: Audio Engine Initialization Crash (FIXED - 2026-01-07)
- **Location**: `AudioDeviceManager.setInputDevice()` at line 70
- **Cause**: `audioEngine.inputNode` access before audio component system initialized
- **Stack**: `AudioComponentFindNext` → `unarchivedObjectOfClass` → `_xzm_xzone_malloc_freelist_outlined`
- **Fix**: Added retry pattern with exponential backoff in `AudioDeviceManager.setInputDevice()`

### Phase 2: Speech Framework Runtime Crash (CURRENT)
- **Location**: Speech framework internal code (Thread 3)
- **Timing**: After all audio engines start, when buffers begin flowing
- **Context**: 4 simultaneous SpeechAnalyzers (LOCAL en-US, LOCAL fr-CA, REMOTE en-US, REMOTE fr-CA)
- **Stack**: All frames in Speech framework (`<unknown>` in Speech)

**Example Stack Trace (Phase 2)**:
```
Thread 3 crashed:
  0 0x00000001d99feb1c <unknown> + 1048 in Speech
  1 0x00000001d9a00ef0 <unknown> + 1132 in Speech
  2 0x00000001d9a111bc <unknown> in Speech
  3 0x00000001d99db5ec <unknown> in Speech
  ...
```

**Phase 1 Example (Fixed)**:
```
Thread 7 crashed:
  0 _xzm_xzone_malloc_freelist_outlined + 864 in libsystem_malloc.dylib
  1 AudioComponentVector::createWithSerializedData(NSData*) + 108 in AudioToolboxCore
  2 AudioDeviceManager.setInputDevice() at AudioDeviceManager.swift:70
     let inputNode = audioEngine.inputNode
```

## Root Cause: Incorrect SpeechAnalyzer API Usage

The crashes were NOT macOS bugs. They were caused by using the SpeechAnalyzer API incorrectly:

### What Was Wrong:
1. ❌ Using `analyzer.start(inputSequence:)` - the autonomous analysis API
2. ❌ Not using `SpeechAnalyzer.bestAvailableAudioFormat()` - hardcoded format instead
3. ❌ Improper task lifecycle management

### The Fix (2026-01-07):
✅ **Changed to `analyzeSequence()` pattern** - Apple's recommended structured concurrency approach
✅ **Used `bestAvailableAudioFormat(compatibleWith:)`** - proper format negotiation
✅ **Proper task ordering** - Start results reading task BEFORE analysis task
✅ **Added retry pattern for `audioEngine.inputNode` access** - handles timing issues

## What We Tried (Historical)
1. ✅ Fixed `TranscriptFileProcessor` thread safety (actor-based)
2. ✅ Added delays between Speech framework initialization (100-200ms)
3. ❌ Added `source` parameter for local/remote tracking - revealed API usage bugs
4. ✅ Built release version successfully
5. 🔄 Stashed speaker identification changes to isolate issue
6. ✅ **2026-01-07**: Fixed audio engine crash with retry pattern + exponential backoff
7. ✅ **2026-01-07**: Fixed Speech framework crash by using correct API patterns

## Stashed Changes (git stash)
The stashed work adds LOCAL/REMOTE speaker identification:
- Added `source: String` parameter throughout SpeechProcessor pipeline
- Modified 10+ files to thread source through
- All tests pass (45/45)
- Transcript output format: `[LOCAL] timestamp: text` or `[REMOTE] timestamp: text`

**Key files modified in stash**:
- `SpeechProcessorProtocol.swift` - Added source parameter
- `SingleLanguageSpeechRecognizer.swift` - Capture source, pass to processors
- `TranscriptFileProcessor.swift` - Prefix transcript lines with source
- `main.swift` - Pass "local" and "remote" to setup functions
- All processor classes (Broadcast, LanguageFilter, Translation, etc.)
- All tests updated with source parameter

## Key Learnings

### SpeechAnalyzer API Patterns
Apple provides two ways to use SpeechAnalyzer:

1. **`analyzeSequence()` - RECOMMENDED** ✅
   - Blocking call that returns when sequence is consumed
   - Integrates with Swift structured concurrency
   - Proper task lifecycle management
   - This is what fixed our crashes

2. **`start()` - ADVANCED** ⚠️
   - Non-blocking, autonomous analysis
   - Requires manual lifecycle management
   - More complex to use correctly
   - We were using this incorrectly

### Proper Initialization Order (from Apple docs)
```swift
// 1. Create modules
let transcriber = SpeechTranscriber(locale: locale, ...)

// 2. Get proper audio format
let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

// 3. Create input stream
let (inputSequence, inputBuilder) = AsyncStream.makeStream(of: AnalyzerInput.self)

// 4. Create analyzer
let analyzer = SpeechAnalyzer(modules: [transcriber])

// 5. Supply audio (in background task)
Task { inputBuilder.yield(...) }

// 6. Start reading results FIRST
Task { for try await result in transcriber.results { ... } }

// 7. THEN start analysis
Task { try await analyzer.analyzeSequence(inputSequence) }
```

## Files Changed in Fix
- **SingleLanguageSpeechRecognizer.swift**:
  - Changed from `analyzer.start()` to `analyzer.analyzeSequence()`
  - Added `analysisTask` property for proper lifecycle
  - Now uses `bestAvailableAudioFormat()` instead of hardcoded format
  - Proper task ordering (results reader before analysis)

- **AudioDeviceManager.swift**:
  - Added retry pattern with exponential backoff for `audioEngine.inputNode` access
  - Made `setInputDevice()` async to support delays

- **AudioEngineService.swift**:
  - Made engine creation methods async

- **main.swift**:
  - Updated to await async audio engine creation

## Next Steps
1. ✅ Test with full dual-audio setup (LOCAL + REMOTE)
2. 🔄 Pop stash to restore speaker identification feature
3. ✅ Update CLAUDE.md with new findings
4. ✅ Commit the fix

## Commands to Resume Work
```bash
# Check if crash is fixed after update
swift build && ./.build/debug/MultilingualRecognizer

# If stable, restore speaker identification work
git stash pop

# Rebuild and test
swift build
swift test

# If tests pass, commit the feature
git add -A
git commit -m "Add local/remote speaker identification to transcripts"
```

## Plan File Reference
Implementation plan exists at: `~/.claude/plans/agile-forging-deer.md`
Contains full specification for LOCAL/REMOTE speaker identification feature.

## Important Files to Remember
- `Sources/MultilingualRecognizer/SingleLanguageSpeechRecognizer.swift:82` - Where crashes occur
- `Sources/MultilingualRecognizer/main.swift` - Setup functions with delays
- `Sources/MultilingualRecognizer/TranscriptFileProcessor.swift` - Actor-based file writer
- Tests pass: 45/45 on last commit

## Debug vs Release
- **Debug build**: Crashes frequently during Speech framework init
- **Release build**: Builds successfully, may be more stable
- Release binary location: `.build/release/MultilingualRecognizer`
