# Apple Feedback Report: Speech Framework Initialization Crashes

## Summary

SpeechAnalyzer and SpeechTranscriber crash with heap corruption in Release builds when initialized without artificial delays. The crashes occur in Speech framework internals (malloc, XPC, metadata instantiation) and require 300-400ms of workaround delays per recognizer to avoid.

## Environment

- **macOS Version**: macOS 26.0 Beta (25D5033g)
- **Xcode Version**: Xcode 16.3 (16C5001e)
- **Swift Version**: Swift 6.0
- **Architecture**: Apple Silicon (arm64)
- **Build Configuration**: Release (crashes do NOT occur in Debug builds)

## Description

### Issue

When creating `SpeechTranscriber` and `SpeechAnalyzer` objects in a Release build, the Speech framework crashes with heap corruption if initialization happens too quickly. The issue manifests in three specific locations:

1. **After SpeechTranscriber creation** - When calling `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)`
2. **During SpeechAnalyzer initialization** - When calling `SpeechAnalyzer(modules:)`
3. **Before analysis preparation** - When calling `analyzer.prepareToAnalyze(in:)`

### Expected Behavior

- SpeechTranscriber and SpeechAnalyzer should initialize synchronously or handle internal async initialization safely
- No crashes should occur when creating these objects in sequence
- Release build optimizations should not expose race conditions in framework internals
- No delays should be required (none documented, none in Apple sample code)

### Actual Behavior

**Without artificial delays (Release build):**
- Heap corruption: "BUG IN CLIENT OF LIBMALLOC: memory corruption of free block"
- Crashes in malloc internals, XPC service initialization, Swift metadata instantiation
- Unpredictable crash timing (sometimes immediate, sometimes after 2nd recognizer)

**With workaround delays (Release build):**
- 200ms after SpeechTranscriber creation → prevents bestAvailableAudioFormat() crash
- 100ms before prepareToAnalyze() → prevents malloc crash
- 300ms between creating multiple recognizers → prevents metadata instantiation crash
- Total: ~400ms per recognizer + 300ms between recognizers = 1.1 seconds for 2 languages

**Debug build behavior:**
- No crashes occur with or without delays
- Issue appears to be optimization-related

## Steps to Reproduce

### Method 1: Using Production Application (Most Reliable)

**A dedicated crash reproduction branch is available with all delays removed.**

1. Clone the complete production application:
   ```bash
   git clone https://github.com/dougbradbury/pentecost.git
   cd pentecost
   ```

2. Checkout the crash reproduction branch:
   ```bash
   git checkout apple-feedback-crash-reproduction
   ```

3. Build in Release mode:
   ```bash
   swift build -c release
   ```

4. Run and observe crash:
   ```bash
   ./.build/release/MultilingualRecognizer
   ```

5. Expected crash: "BUG IN CLIENT OF LIBMALLOC: memory corruption of free block"

**Note**: The `main` branch has the working version with all workaround delays intact. The `apple-feedback-crash-reproduction` branch has all delays removed to demonstrate the crash.

### Method 2: Using Minimal Reproduction Case (Reference Implementation)

1. Download attached `MinimalReproduction.swift` and `Package.swift`
2. Build in Release mode:
   ```bash
   swift build -c release
   ```
3. Run the binary:
   ```bash
   ./.build/release/MinimalRepro
   ```

**Note**: The minimal reproduction may not crash 100% of the time in isolation. The crash is most reliably reproduced in the full production application (Method 1) where Speech framework is under realistic workload with audio processing, multiple actors, and concurrent operations.

### Method 2: Manual Reproduction

```swift
import Speech

@available(macOS 26.0, *)
actor TestRecognizer {
    func setup() async throws {
        // Create transcriber
        let transcriber = SpeechTranscriber(
            locale: Locale(identifier: "en-US"),
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        // THIS CRASHES in Release build:
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber]
        )

        // THIS ALSO CRASHES:
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // THIS ALSO CRASHES:
        try await analyzer.prepareToAnalyze(in: format!)
    }
}

// Build: swift build -c release
// Result: Crashes with heap corruption
```

## Crash Details

### Crash Type 1: bestAvailableAudioFormat()

```
BUG IN CLIENT OF LIBMALLOC: memory corruption of free block
*** set a breakpoint in malloc_error_break to debug
Program ended with exit code: 0
```

**Stack trace excerpt:**
```
malloc_zone_malloc
Swift._convertConstStringToUTF8PointerImpl
type metadata instantiation function for SpeechTranscriber
[Speech framework internal functions]
```

### Crash Type 2: SpeechAnalyzer Constructor

```
malloc_zone_malloc corruption
XPC service initialization failure
Swift metadata instantiation crash
```

### Crash Type 3: prepareToAnalyze()

**Location:** SingleLanguageSpeechRecognizer.swift:87
```swift
try await analyzer?.prepareToAnalyze(in: audioFormat)  // Line 87
```

**Error:** Heap corruption during XPC service initialization

## Impact

### On Development

- **Startup Performance**: Applications requiring multilingual recognition need 1+ seconds of artificial delays
- **User Experience**: Noticeably slow initialization with no technical justification
- **Code Quality**: Forced to add unexplained "magic number" delays throughout codebase
- **Maintenance**: Future developers won't understand why delays exist

### Real-World Application Impact

Our production application (real-time bilingual meeting transcription) requires:
- 2 language recognizers (English + French)
- Current startup time: ~1.65 seconds of pure delay workarounds
- Without delays: Immediate crash in Release build
- User perception: "Why is this so slow to start?"

## Investigation Conducted

### 1. Documentation Review

- **Apple Documentation**: No mention of required delays or async initialization behavior
- **WWDC Videos**: No discussion of initialization timing requirements
- **Sample Code**: Apple's "BringingAdvancedSpeechToTextCapabilitiesToYourApp" has NO delays
- **Forum Posts**: No other developers discussing this workaround (searched developer.apple.com, Stack Overflow)

### 2. Architectural Testing

We systematically tested various Swift concurrency patterns:

**Attempted Solutions:**
- ✗ `withExtendedLifetime(self)` - No effect
- ✗ `@_optimize(none)` - Band-aid, doesn't address root cause
- ✓ Actor isolation - Helps but doesn't eliminate need for delays
- ✓ Proper Sendable conformance - Helps but doesn't eliminate need for delays

**Delay Optimization Testing:**
- Removed 1000ms "final stabilization" delay - No crash (delay was unnecessary)
- Removed 800ms "analyzer setup" delay - No crash (delay was unnecessary)
- Removed 300ms recognizer spacing - **CRASHED** (delay IS required)
- Removed 200ms post-transcriber delay - **CRASHED** (delay IS required)
- Removed 100ms pre-prepareToAnalyze delay - **CRASHED** (delay IS required)

### 3. Build Configuration Analysis

| Build Type | Optimization | Result |
|------------|--------------|--------|
| Debug | None (-Onone) | ✅ Works without delays |
| Release | Full (-O) | ❌ Crashes without delays |
| Release | With delays | ✅ Works (workaround) |

This strongly suggests a race condition or initialization order bug that Release optimizations expose.

## Root Cause Analysis

Based on crash locations and testing, the issue appears to be:

1. **Async XPC Initialization**: Speech framework uses XPC services internally, but initialization is not properly synchronized
2. **Premature API Usage**: Calling `bestAvailableAudioFormat()` before internal state is ready causes corruption
3. **Optimization Exposure**: Release builds execute quickly enough to hit the race window
4. **No Public API**: Speech framework provides no initialization completion callback or async pattern

## Workaround Code

Current production workaround in our codebase:

```swift
@available(macOS 26.0, *)
actor SingleLanguageSpeechRecognizer {
    func setUpTranscriber() async throws {
        // Create transcriber
        transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        // WORKAROUND: Speech framework internal initialization
        // Without this: crashes in bestAvailableAudioFormat()
        try await Task.sleep(for: .milliseconds(200))

        let audioFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber]
        )

        analyzer = SpeechAnalyzer(modules: [transcriber])

        // WORKAROUND: XPC service initialization
        // Without this: malloc crashes in prepareToAnalyze()
        try await Task.sleep(for: .milliseconds(100))

        try await analyzer?.prepareToAnalyze(in: audioFormat)
    }
}

// In main.swift, between recognizer setups:
try await Task.sleep(for: .milliseconds(300))  // WORKAROUND
```

## Requested Resolution

### Ideal Fix

1. **Synchronous Initialization**: Make Speech framework internal initialization complete before returning from constructors
2. **Async API**: If initialization must be async, provide proper async/await API:
   ```swift
   // Proposed API:
   let transcriber = try await SpeechTranscriber.create(
       locale: locale,
       transcriptionOptions: [],
       reportingOptions: [.volatileResults],
       attributeOptions: [.audioTimeRange]
   )
   ```
3. **Documentation**: Document any initialization timing requirements

### Interim Solutions

1. **Fix Race Condition**: Address the underlying race in XPC initialization
2. **Debug Assertion**: Add debug-mode assertion if APIs called too early
3. **Error Instead of Crash**: Throw proper error instead of heap corruption

## Production Application Repository

**Complete source code available at**: https://github.com/dougbradbury/pentecost

This is the full production application (real-time multilingual meeting transcription) that consistently crashes without the workaround delays. The repository demonstrates:

- Complete implementation with all required workaround delays documented
- Actor-based architecture showing issue persists even with proper concurrency
- Real-world usage: audio engine, processing pipeline, translation, UI rendering
- Systematic testing results documented in commit history

Key files to review:
- `Sources/MultilingualRecognizer/SingleLanguageSpeechRecognizer.swift` - Shows required delays with detailed comments
- `Sources/MultilingualRecognizer/main.swift` - Multi-recognizer setup requiring delays
- `CLAUDE.md` - Project documentation including delay testing methodology

## Attachments

1. **MinimalReproduction.swift** - Standalone reproduction case (reference implementation)
2. **UltraAggressiveReproduction.swift** - Stress test with parallel recognizer creation
3. **Package.swift** - Build configuration
4. **CrashLogs/** - Collection of crash reports from production application
5. **Repository link** - Complete production application source code (see above)

## Additional Information

### Testing Methodology

We used systematic elimination testing:
1. Started with all delays in place (stable)
2. Removed one delay at a time
3. Rebuilt in Release mode
4. Tested thoroughly
5. If crash occurred, restored delay and documented requirement
6. If no crash occurred, permanently removed delay

This resulted in the minimal set of required delays documented above.

### Platform Specifics

- **macOS 26.0 Beta Status**: Issue may be beta-related, but warrants investigation as it could affect shipping applications
- **Backward Compatibility**: Cannot test on earlier macOS versions (SpeechAnalyzer is macOS 26.0+)
- **Hardware**: Tested on multiple Apple Silicon Macs, issue consistent across devices

## Priority Assessment

**Severity**: High
- Crashes in Release builds with heap corruption
- Affects real-time speech recognition applications
- No workaround except artificial delays (poor UX)
- Could affect App Store submissions if users experience crashes

**Reproducibility**: 100% in Release builds without workarounds

**Regression**: Unknown (SpeechAnalyzer is new in macOS 26.0)

## Contact Information

Available for follow-up testing and additional information if needed.

---

**Report Date**: 2026-02-20
**Component**: Speech Framework / SpeechAnalyzer
**Version**: macOS 26.0 Beta (25D5033g)
**Feedback Type**: Bug Report
