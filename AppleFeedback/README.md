# Apple Feedback Submission Package

This directory contains a complete bug report package for submission to Apple's Feedback Assistant regarding Speech framework initialization crashes in macOS 26.0.

## Quick Links

- **Main Report**: [FeedbackReport.md](FeedbackReport.md) - Comprehensive bug description and analysis
- **Reproduction Code**: [MinimalReproduction.swift](MinimalReproduction.swift) - Standalone demonstration
- **Crash Analysis**: [CrashLogs/README.md](CrashLogs/README.md) - Detailed crash log analysis

## Issue Summary

**Component**: Speech Framework (SpeechAnalyzer/SpeechTranscriber)
**Platform**: macOS 26.0 Beta (25D125)
**Severity**: High - Crashes with heap corruption in Release builds
**Production App**: https://github.com/dougbradbury/pentecost
**Crash Reproduction**: `git checkout apple-feedback-crash-reproduction`

SpeechAnalyzer and SpeechTranscriber crash with "BUG IN CLIENT OF LIBMALLOC: memory corruption of free block" when initialized without artificial delays. The crashes only occur in Release builds and require 300-400ms of workaround delays per recognizer.

**Full production application available** at the repository link above. The `main` branch has working code with delays. The `apple-feedback-crash-reproduction` branch has all delays removed and crashes consistently.

## What's Included

### 1. FeedbackReport.md
Comprehensive bug report including:
- Complete environment details
- Expected vs actual behavior
- Step-by-step reproduction instructions
- Root cause analysis
- Impact assessment
- Workaround code
- Recommendations for Apple

### 2. MinimalReproduction.swift
Standalone Swift file demonstrating the issue:
- Version WITHOUT delays (crashes)
- Version WITH delays (works as workaround)
- Toggle flag to test both scenarios
- Comprehensive inline documentation

### 3. Package.swift
Swift Package Manager configuration to build the minimal reproduction case:
```bash
cd AppleFeedback
swift build -c release
./.build/release/MinimalRepro
```

### 4. CrashLogs/
Directory containing:
- Representative crash logs from production testing
- Detailed analysis of crash patterns
- Stack trace annotations
- Timing requirement documentation

## How to Use This Package

### For Apple Engineers

1. **Read**: Start with [FeedbackReport.md](FeedbackReport.md) for complete context
2. **Build**: Use `Package.swift` to build the minimal reproduction
3. **Test**: Toggle `useWorkaround = false` in MinimalReproduction.swift to see crash
4. **Analyze**: Review crash logs in CrashLogs/ directory for detailed stack traces

### For Submitting Feedback

1. **File Feedback**: Use Apple Feedback Assistant (feedback.apple.com)
2. **Component**: Select "Speech Framework" or "Developer Tools > Speech Recognition"
3. **Description**: Copy relevant sections from FeedbackReport.md
4. **Attachments**: Include all files from this directory
5. **Reproducibility**: Mark as "Always" (100% reproducible in Release builds)

## Key Findings

### The Problem
Creating SpeechTranscriber and SpeechAnalyzer objects too quickly causes heap corruption crashes in Speech framework internals. Three specific crash points:

1. After SpeechTranscriber creation (bestAvailableAudioFormat call)
2. After SpeechAnalyzer creation (prepareToAnalyze call)
3. When creating multiple recognizers in sequence

### Required Workarounds
- 200ms delay after each SpeechTranscriber creation
- 100ms delay before each prepareToAnalyze() call
- 300ms delay between creating multiple recognizers
- **Total impact**: 1.1+ seconds startup delay for bilingual recognition

### Why This Is Definitely a Bug
1. ❌ No documentation mentions delays
2. ❌ Apple's sample code has no delays
3. ❌ No community discussion of this workaround
4. ❌ Crashes occur in framework internals, not app code
5. ❌ Only happens in Release builds (optimization-related race)
6. ✅ Appears to be XPC service initialization race condition

## Testing Details

### Systematic Delay Elimination
We tested removing each delay individually to find the minimum required set:

| Delay Removed | Build | Result |
|---------------|-------|--------|
| 1000ms final stabilization | Release | ✅ No crash - removed |
| 800ms analyzer setup | Release | ✅ No crash - removed |
| 300ms recognizer spacing | Release | ❌ **CRASHED** - required |
| 200ms post-transcriber | Release | ❌ **CRASHED** - required |
| 100ms pre-prepareToAnalyze | Release | ❌ **CRASHED** - required |

### Build Configuration Impact
- **Debug build (-Onone)**: Works perfectly without any delays
- **Release build (-O)**: Crashes without all three required delays
- **Release with delays**: Works but has 1+ second startup penalty

## Impact on Real Applications

Our production application (Pentecost - multilingual meeting transcription):
- **Requires**: 2 simultaneous language recognizers (English + French)
- **Current startup time**: 1.65 seconds of pure workaround delays
- **User experience**: "Why is this app so slow to start?"
- **Code quality**: Unexplained magic numbers throughout codebase
- **Maintainability**: Future developers won't understand why delays exist

## Expected Apple Response

We hope Apple will:

1. **Acknowledge**: Confirm this is a framework bug (not expected behavior)
2. **Fix**: Make Speech framework initialization properly synchronous or awaitable
3. **Document**: If delays are somehow intentional, document them clearly
4. **Timeline**: Provide expected fix release (26.1? 27.0?)

## Alternative Solutions Apple Could Provide

1. **Async Initialization API**:
   ```swift
   let transcriber = try await SpeechTranscriber.create(locale: locale, ...)
   ```

2. **Readiness Check**:
   ```swift
   try await transcriber.waitUntilReady()
   ```

3. **Proper Error Handling**:
   Instead of crashing with heap corruption, throw proper errors if APIs called too early

## Contact & Follow-up

This bug report was prepared by the Pentecost development team after extensive testing and analysis. We're available for:
- Additional testing
- Follow-up questions
- Beta testing of fixes
- Providing production app for testing

## File Manifest

```
AppleFeedback/
├── README.md (this file)
├── FeedbackReport.md (detailed bug report)
├── MinimalReproduction.swift (reproduction code)
├── Package.swift (build configuration)
└── CrashLogs/
    ├── README.md (crash analysis)
    ├── crash_bestAvailableAudioFormat.ips
    ├── crash_prepareToAnalyze.ips
    └── crash_metadata_instantiation.ips
```

## Version History

- **2026-02-20**: Initial feedback package created
  - Comprehensive analysis after 3 days of systematic testing
  - Eliminated 1.8s of unnecessary delays
  - Documented minimum required delays
  - Created minimal reproduction case

## Related Radars/Feedback

*None found - this appears to be a newly discovered issue*

---

**Next Steps**: Submit via feedback.apple.com and monitor for Apple response
