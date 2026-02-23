# Crash Reproduction Branch

**Branch**: `apple-feedback-crash-reproduction`

## Purpose

This branch has all workaround delays **REMOVED** to demonstrate the Speech framework crashes that occur in macOS 26.0 Beta when using SpeechAnalyzer and SpeechTranscriber.

## What Was Changed

All `Task.sleep()` delays have been removed from:

1. **SingleLanguageSpeechRecognizer.swift**:
   - ❌ Removed 200ms delay after SpeechTranscriber creation (line 57)
   - ❌ Removed 100ms delay before prepareToAnalyze() (line 83)
   - ❌ Removed 50ms delay for task scheduling (line 137)

2. **main.swift**:
   - ❌ Removed 300ms delay between English and French recognizer setup (LOCAL)
   - ❌ Removed 300ms delay before audio engine creation (LOCAL)
   - ❌ Removed 300ms delay between English and French recognizer setup (REMOTE)
   - ❌ Removed 300ms delay before audio engine creation (REMOTE)

**Total delays removed**: ~1.65 seconds

## How to Reproduce the Crash

### 1. Checkout this branch:
```bash
git checkout apple-feedback-crash-reproduction
```

### 2. Build in Release mode:
```bash
swift build -c release
```

### 3. Run the application:
```bash
./.build/release/MultilingualRecognizer
```

### 4. Observe the crash:
```
BUG IN CLIENT OF LIBMALLOC: memory corruption of free block
```

The crash will occur at one of these locations:
- During `bestAvailableAudioFormat()` call
- During `prepareToAnalyze()` call
- When creating the second recognizer
- During audio engine startup

## Expected vs Actual Behavior

### Expected (macOS 26.0 should work like this):
- ✅ Speech framework initialization should be synchronous or properly async
- ✅ No crashes when creating recognizers in sequence
- ✅ No artificial delays required
- ✅ XPC services should initialize safely

### Actual (macOS 26.0 Beta behavior):
- ❌ Crashes with heap corruption
- ❌ Speech framework internal XPC race conditions
- ❌ Swift metadata instantiation crashes
- ❌ Requires 1.65+ seconds of artificial delays as workaround

## Comparison with Working Branch

To see the working version with workarounds:

```bash
git checkout main
swift build -c release
./.build/release/MultilingualRecognizer
```

The `main` branch includes all necessary delays and runs without crashes.

## For Apple Engineers

This branch provides the easiest way to reproduce the issue:

1. Clone the repository
2. Checkout `apple-feedback-crash-reproduction`
3. Build in Release mode
4. Run and observe crash

No manual editing required - the branch is ready to crash.

### Switching between versions:

**Crash version** (this branch):
```bash
git checkout apple-feedback-crash-reproduction
swift build -c release
./.build/release/MultilingualRecognizer  # Will crash
```

**Working version** (main branch with workarounds):
```bash
git checkout main
swift build -c release
./.build/release/MultilingualRecognizer  # Works with delays
```

## Technical Details

### Crash Characteristics:
- **Only in Release builds** (-O optimization)
- **Heap corruption**: "BUG IN CLIENT OF LIBMALLOC"
- **Exception Type**: EXC_BREAKPOINT (SIGTRAP), Signal 5
- **Crash Locations**: malloc internals, XPC services, Swift metadata

### System Requirements:
- macOS 26.0 Beta or later
- Apple Silicon or Intel
- Release build configuration

### Evidence:
See `/AppleFeedback/` directory for:
- Complete crash logs
- Detailed analysis
- Minimal reproductions
- Apple Feedback report

## Related Files

- **AppleFeedback/FeedbackReport.md** - Complete bug report
- **AppleFeedback/CrashLogs/** - Real crash logs from testing
- **AppleFeedback/READY_TO_SUBMIT.md** - Submission checklist

## Issue Summary

Speech framework in macOS 26.0 Beta has race conditions in internal XPC service initialization that cause crashes when:
1. Querying audio format too quickly after transcriber creation
2. Calling prepareToAnalyze too quickly after analyzer creation
3. Creating multiple recognizers without delays between them

The workarounds (delays) mask these race conditions but don't fix the underlying framework bug.

---

**Created**: 2026-02-20
**Purpose**: Apple Feedback crash reproduction
**Repository**: https://github.com/dougbradbury/pentecost
**Branch**: apple-feedback-crash-reproduction
