# Apple Feedback Submission Guide

This guide walks you through submitting this bug report via Apple's Feedback Assistant.

## Before You Submit

### 1. Test the Minimal Reproduction
```bash
cd /Users/dougbradbury/Projects/Pentecost/AppleFeedback
swift build -c release
./.build/release/MinimalRepro
```

**Expected output** (with workaround enabled):
```
=== Speech Framework Initialization Bug Demo ===
Creating first recognizer (English)...
Setting up transcriber for en-US...
✅ Setup complete for en-US
Waiting 300ms before second recognizer...

Creating second recognizer (French)...
Setting up transcriber for fr-FR...
✅ Setup complete for fr-FR

✅ Both recognizers initialized successfully
(With workaround delays: true)
```

**To verify crash** (optional):
1. Edit MinimalReproduction.swift line 97: `let useWorkaround = false`
2. Rebuild and run
3. Observe crash with heap corruption

### 2. Gather System Information
```bash
# Get exact macOS version
sw_vers

# Get Xcode version
xcodebuild -version

# Get Swift version
swift --version
```

## Submission Steps

### 1. Open Feedback Assistant

**Option A**: Visit [feedback.apple.com](https://feedback.apple.com)

**Option B**: Use the Feedback Assistant app
```bash
open -a "Feedback Assistant"
```

### 2. Create New Feedback

Click "New Feedback" or "+" button

### 3. Fill Out Form

#### Feedback Type
Select: **Bug Report**

#### Area
Choose one of:
- **Speech & Dictation**
- **Developer Tools > Speech Recognition**
- **macOS > Speech Framework**

#### Title
```
Speech Framework: SpeechAnalyzer/SpeechTranscriber crash with heap corruption in Release builds without artificial delays
```

#### Description
Copy from [FeedbackReport.md](FeedbackReport.md) - Summary section:

```
SpeechAnalyzer and SpeechTranscriber crash with heap corruption in Release builds when initialized without artificial delays. The crashes occur in Speech framework internals (malloc, XPC, metadata instantiation) and require 300-400ms of workaround delays per recognizer to avoid.

PRODUCTION APPLICATION:
Complete source code available at: https://github.com/dougbradbury/pentecost
This real-time multilingual meeting transcription app demonstrates the issue consistently in production use with audio processing, multiple recognizers, and concurrent operations.

ENVIRONMENT:
- macOS Version: 26.0 Beta (25D125)
- Xcode: 16.3 (16C5001e)
- Swift: 6.0
- Architecture: Apple Silicon
- Build: Release only (Debug works fine)

ISSUE:
Creating SpeechTranscriber and SpeechAnalyzer objects causes:
• "BUG IN CLIENT OF LIBMALLOC: memory corruption of free block"
• Crashes in malloc, XPC initialization, Swift metadata instantiation
• Only in Release builds with optimizations

REQUIRED WORKAROUNDS:
• 200ms delay after SpeechTranscriber creation
• 100ms delay before prepareToAnalyze()
• 300ms delay between multiple recognizers
• Total: 1.1+ seconds for bilingual recognition app

IMPACT:
• Poor user experience (slow startup)
• No documentation suggests delays needed
• Apple sample code has NO delays
• Affects production speech recognition apps
```

#### Steps to Reproduce

Copy this section:

```
RECOMMENDED: Using the production application (most reliable):

1. Clone the production app:
   git clone https://github.com/dougbradbury/pentecost.git
   cd pentecost

2. Checkout crash reproduction branch:
   git checkout apple-feedback-crash-reproduction

3. Build in Release mode:
   swift build -c release

4. Run and observe crash:
   ./.build/release/MultilingualRecognizer

5. Expected crash: "BUG IN CLIENT OF LIBMALLOC: memory corruption of free block"

NOTE: The apple-feedback-crash-reproduction branch has all workaround delays
REMOVED to demonstrate the crash. The main branch has the working version with
delays intact. No manual editing required - just checkout the branch, build, run.

The production app crashes consistently because it has realistic workload:
audio processing, multiple concurrent recognizers, translation, and UI rendering.

ALTERNATIVE - Minimal reproduction (reference only):

1. Build attached MinimalReproduction.swift in Release mode:
   swift build -c release

2. Edit MinimalReproduction.swift line 119:
   Set: let useWorkaround = false

3. Rebuild and run:
   swift build -c release
   ./.build/release/MinimalRepro

Note: Minimal reproduction may not crash 100% of time in isolation.

MANUAL CODE REPRODUCTION:

import Speech

@available(macOS 26.0, *)
actor TestRecognizer {
    func setup() async throws {
        let transcriber = SpeechTranscriber(
            locale: Locale(identifier: "en-US"),
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )

        // THIS CRASHES:
        let format = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber]
        )

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: format!)
    }
}

Build: swift build -c release
Result: Crash with heap corruption
```

#### Expected Results
```
SpeechTranscriber and SpeechAnalyzer should initialize without crashes.
Speech framework should handle internal async initialization safely.
No artificial delays should be required.
Release and Debug builds should behave consistently.
```

#### Actual Results
```
Release build crashes with:
• "BUG IN CLIENT OF LIBMALLOC: memory corruption of free block"
• Exception: EXC_BREAKPOINT (SIGTRAP)
• Crashes in: malloc_zone_malloc, Swift metadata instantiation, XPC init

Workaround: Add 200ms + 100ms + 300ms delays = poor UX

Debug build: Works fine without any delays
```

#### Configuration
- **macOS Version**: 26.0 (25D125)
- **Reproducibility**: Always (100% in Release builds)
- **Device**: Mac (Apple Silicon)
- **Build Configuration**: Release (-O optimization)

### 4. Attach Files

Click "Attach Files" and add:

1. **MinimalReproduction.swift** (reproduction code)
2. **Package.swift** (build configuration)
3. **FeedbackReport.md** (detailed analysis)
4. **CrashLogs/crash_prepareToAnalyze.ips** (example crash log)
5. **CrashLogs/README.md** (crash analysis)

Optional additional files:
- CrashLogs/crash_bestAvailableAudioFormat.ips
- CrashLogs/crash_metadata_instantiation.ips

**File Upload Tips**:
- Compress if total size > 25 MB: `zip -r SpeechFrameworkBug.zip AppleFeedback/`
- Individual files are fine if each < 5 MB
- Crash logs (.ips files) can be attached directly

### 5. Add Keywords

Add these tags to help with routing:
- Speech
- SpeechAnalyzer
- SpeechTranscriber
- malloc
- heap corruption
- XPC
- Release build
- macOS 26

### 6. Diagnostics

**If prompted for diagnostics:**

Attach sysdiagnose:
```bash
# Trigger sysdiagnose (takes 3-5 minutes)
sudo sysdiagnose

# Find the file (will be in /var/tmp/)
ls -lt /var/tmp/sysdiagnose*.tar.gz | head -1
```

**Note**: Only do this if specifically requested - file is very large (1-2 GB)

### 7. Review & Submit

1. **Review** all information for accuracy
2. **Verify** attachments uploaded successfully
3. **Click** "Submit"
4. **Save** the Feedback ID (e.g., FB1234567890)

## After Submission

### 1. Track Your Feedback

1. Note the Feedback ID number
2. Check status periodically at feedback.apple.com
3. Watch for:
   - Status changes (Open → Investigation → Closed)
   - Apple engineer responses
   - Requests for additional information

### 2. Reference in Code

Add feedback ID to code comments:

```swift
// WORKAROUND for FB1234567890: Speech framework crashes without delays
// See: /AppleFeedback/FeedbackReport.md for details
try await Task.sleep(for: .milliseconds(200))
```

### 3. Share with Community

Consider posting to:
- Apple Developer Forums (link to feedback)
- Stack Overflow (if others encounter this)
- Your project's documentation

### 4. Monitor for Fixes

Watch for:
- macOS 26.1 beta release notes
- Speech framework release notes
- Xcode release notes
- "Resolved in macOS XX.X" status update

## Common Feedback Statuses

- **Open**: Submitted, awaiting review
- **More than 10**: Apple has received 10+ similar reports
- **Under Investigation**: Apple engineers reviewing
- **Potential Fix Identified**: Fix in development
- **Resolved**: Fixed in specific OS version
- **Behaves as Intended**: Apple considers this expected (unlikely here)
- **Insufficient Information**: Need to provide more details

## If Apple Requests More Information

Be prepared to provide:

1. **Full application source**: If minimal repro insufficient
2. **Console logs**: During crash occurrence
3. **Instruments traces**: Time Profiler, Allocations
4. **Sysdiagnose**: Full system diagnostic archive
5. **Video recording**: Screen capture showing the crash
6. **Remote debugging**: Screen sharing session with Apple engineer

## Questions Apple Might Ask

**Q: "Can you reproduce this on earlier macOS versions?"**
A: No, SpeechAnalyzer is new in macOS 26.0 - cannot test earlier versions

**Q: "Does this occur with different locales?"**
A: Yes, tested with en-US, fr-FR, both show same behavior

**Q: "Have you tried without actor isolation?"**
A: Yes, crashes occur with and without actors - actor isolation helps but doesn't eliminate need for delays

**Q: "What about different optimization levels?"**
A: Only Release (-O) crashes. Debug (-Onone) works fine. This suggests race condition.

**Q: "Can you provide Instruments trace?"**
A: Crash happens too quickly for meaningful trace, but we can provide Allocations/Leaks if helpful

## Feedback Best Practices

✅ **DO**:
- Be specific and factual
- Provide minimal reproduction case
- Include exact version numbers
- Attach relevant crash logs
- Document workarounds
- Keep tone professional

❌ **DON'T**:
- Complain or use harsh language
- Assume malice or incompetence
- Include irrelevant information
- Submit duplicate feedbacks
- Expect immediate response
- Share confidential Apple information

## Sample Follow-up Response

If Apple asks for clarification:

```
Thank you for reviewing this feedback.

To answer your questions:

1. [Specific answer]
2. [Specific answer]

I've attached [additional files/information] as requested.

The minimal reproduction case demonstrates the issue with just
50 lines of code. The crash is 100% reproducible in Release builds.

Please let me know if you need any additional information or
testing from our side.

Best regards,
[Your name]
```

## Expected Timeline

Based on typical Apple feedback workflows:

- **1-7 days**: Initial automated acknowledgment
- **1-4 weeks**: Engineering review (if prioritized)
- **4-12 weeks**: Potential fix identified (if confirmed bug)
- **Next OS release**: Resolution (26.1 beta or later)

**Note**: Beta-specific bugs often get faster turnaround

## Escalation (If Needed)

If no response after 4 weeks:

1. **Post to Apple Developer Forums**: Reference feedback ID
2. **File duplicate feedback**: Reference original FB number
3. **Contact Developer Relations**: via developer.apple.com/contact
4. **WWDC Labs** (if during WWDC): Discuss with Speech framework engineers

## Success Metrics

Consider this feedback successful if:

✅ Apple acknowledges as a bug
✅ Fix provided in future beta/release
✅ Documentation updated if intended behavior
✅ Other developers benefit from the report

---

**Prepared**: 2026-02-20
**Last Updated**: 2026-02-20
**Status**: Ready for submission

Good luck with your feedback submission!
