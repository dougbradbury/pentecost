# Crash Log Analysis

This directory contains representative crash logs demonstrating the Speech framework initialization bugs in macOS 26.0.

## Crash Categories

### 1. bestAvailableAudioFormat() Crash
**File:** `crash_bestAvailableAudioFormat.ips`

**When:** Calling `SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)` immediately after SpeechTranscriber creation

**Error Message:**
```
BUG IN CLIENT OF LIBMALLOC: memory corruption of free block
```

**Stack Trace Pattern:**
- malloc_zone_malloc
- Swift._convertConstStringToUTF8PointerImpl
- type metadata instantiation for SpeechTranscriber
- [Speech framework internals]

**Fix:** Add 200ms delay after SpeechTranscriber creation before calling bestAvailableAudioFormat()

### 2. prepareToAnalyze() Crash
**File:** `crash_prepareToAnalyze.ips`

**When:** Calling `analyzer.prepareToAnalyze(in: audioFormat)` immediately after SpeechAnalyzer creation

**Error Message:**
```
BUG IN CLIENT OF LIBMALLOC: memory corruption of free block
Abort Cause 33630824448
```

**Key Details:**
- **Crash Location:** Line 87 in SingleLanguageSpeechRecognizer.swift
- **Thread:** com.apple.root.user-initiated-qos.cooperative (async task)
- **Exception Type:** EXC_BREAKPOINT (SIGTRAP)

**Stack Trace:**
```
#0  _xzm_xzone_malloc_freelist_outlined (heap corruption detected)
#1  operator_new_impl[abi:ne200100]
#2  swift::Demangle::__runtime::TypeDecoder::decodeMangledType
#3  swift_getTypeByMangledNodeImpl
#4  swift_getTypeByMangledName
#5  closure #1 in SingleLanguageSpeechRecognizer.setUpTranscriber()
```

**Analysis:**
- Crash occurs during Swift metadata instantiation
- Speech framework internal XPC service not fully initialized
- Memory allocator detects corruption in freed block
- Issue appears to be race condition in framework initialization

**Fix:** Add 100ms delay after SpeechAnalyzer() creation before calling prepareToAnalyze()

### 3. Multiple Recognizer Instantiation Crash
**File:** `crash_metadata_instantiation.ips`

**When:** Creating a second SpeechTranscriber/SpeechAnalyzer pair too quickly after the first

**Error Message:**
```
BUG IN CLIENT OF LIBMALLOC: memory corruption of free block
```

**Stack Trace Pattern:**
- malloc corruption detected
- Swift type metadata instantiation
- Second recognizer setup in main.swift

**Analysis:**
- Speech framework appears to have shared global state
- XPC service initialization not thread-safe or properly serialized
- Creating second recognizer before first is fully initialized causes corruption
- Debug builds work fine (timing differences hide the race)

**Fix:** Add 300ms delay between recognizer setup calls

## Common Patterns Across All Crashes

### Crash Characteristics
1. **Build-Specific**: Only occurs in Release builds (-O optimization)
2. **Malloc Corruption**: All crashes show heap corruption in libsystem_malloc
3. **XPC Related**: Speech framework uses XPC services that aren't ready
4. **Metadata Issues**: Swift type metadata instantiation triggers allocation failures
5. **Non-Deterministic**: Sometimes crashes immediately, sometimes on 2nd recognizer

### System Information
- **macOS Version**: 26.3 (25D125) - Beta release
- **Architecture**: ARM-64 (Apple Silicon)
- **Exception Types**: EXC_BREAKPOINT (SIGTRAP) / Signal 5
- **Developer Mode**: Enabled
- **SIP Status**: Enabled

### Thread Analysis

**Triggering Thread:**
- Always in cooperative async task queue: `com.apple.root.user-initiated-qos.cooperative`
- Swift concurrency runtime executing actor-isolated code
- Crashes during allocation for Swift metadata

**Other Active Threads:**
- Main thread (blocked in runloop)
- Audio threads: AudioSession - RootQueue
- Core Audio threads: caulk.messenger.shared queues
- Swift async worker threads

### Memory State

**Crash Details from ASI (Application Specific Information):**
```json
"asi" : {
  "libsystem_malloc.dylib": [
    "BUG IN CLIENT OF LIBMALLOC: memory corruption of free block",
    "Abort Cause 33630824448"
  ]
}
```

This indicates the malloc allocator detected corruption in a previously freed memory block, suggesting:
1. Use-after-free in Speech framework
2. Double-free in Speech framework
3. Buffer overflow corrupting heap metadata

## Timing Requirements Discovered

Through systematic testing, the minimum delays required to prevent crashes:

| Location | Delay | Removable? | Notes |
|----------|-------|------------|-------|
| After SpeechTranscriber creation | 200ms | ❌ No | Crashes in bestAvailableAudioFormat() |
| Before prepareToAnalyze() | 100ms | ❌ No | Crashes in malloc during XPC init |
| Between recognizer setups | 300ms | ❌ No | Crashes on 2nd recognizer metadata |
| After all setup (final) | 50ms | ✅ Yes | Tasks start async, optional buffer |
| Old "stabilization" delay | 1000ms | ✅ Yes | Was unnecessary |
| Old "analyzer setup" delay | 800ms | ✅ Yes | Was unnecessary |

**Total Required Delays:**
- Single recognizer: 300ms (200ms + 100ms)
- Two recognizers: 1.3 seconds (300ms + 300ms + 300ms + 300ms + 100ms)
- Four recognizers (our app): 1.65 seconds total

## Evidence This Is a Framework Bug

1. **No Documentation**: Apple's Speech framework documentation mentions nothing about initialization timing
2. **No Sample Code Delays**: Apple's official sample code "BringingAdvancedSpeechToTextCapabilitiesToYourApp" has NO delays
3. **No Community Reports**: No Stack Overflow, Developer Forums, or blog posts about this workaround
4. **Framework Internal Crashes**: All crashes occur in Speech framework internals, not application code
5. **Debug vs Release**: Issue only appears with compiler optimizations (race condition)
6. **Beta Status**: macOS 26.0 is beta, Speech framework may have known issues

## Recommendations for Apple

1. **Immediate Fix**: Make Speech framework initialization synchronous or properly awaitable
2. **Proper Async API**: If initialization is async, expose completion handlers/continuations
3. **XPC Initialization**: Ensure XPC services are ready before returning from constructors
4. **Documentation**: Document any timing requirements (if intentional)
5. **Debug Assertions**: Add assertions to catch premature API usage instead of crashing
6. **Testing**: Add Release build tests to catch optimization-related race conditions

## Files Included

- `crash_bestAvailableAudioFormat.ips` - Crash when querying audio format too early
- `crash_prepareToAnalyze.ips` - Crash when preparing analyzer too early
- `crash_metadata_instantiation.ips` - Crash when creating second recognizer too quickly

## Additional Context

See the main feedback report (`../FeedbackReport.md`) for:
- Detailed reproduction steps
- Minimal reproduction code
- Complete workaround implementation
- Full system environment details
- Impact analysis on real applications
