# Pentecost Hooks System

Pentecost includes a flexible hook system that allows you to run custom commands when certain events occur, such as when a transcript ends or a new one starts.

## Quick Start

1. **Create configuration directory**:
   ```bash
   mkdir -p ~/.pentecost/scripts
   ```

2. **Copy example configuration**:
   ```bash
   cp hooks.yaml.example ~/.pentecost/hooks.yaml
   ```

3. **Copy example script**:
   ```bash
   cp scripts/claude-summarize.sh.example ~/.pentecost/scripts/claude-summarize.sh
   chmod +x ~/.pentecost/scripts/claude-summarize.sh
   ```

4. **Edit configuration** to enable hooks:
   ```bash
   nano ~/.pentecost/hooks.yaml
   ```

5. **Enable a hook** by changing `enabled: false` to `enabled: true`

## Available Events

### `on_transcript_end`
Triggered when a transcript ends, either by:
- Application shutdown (Ctrl-C)
- Starting a new transcript (Ctrl-N)

**Context variables**:
- `{transcript_file}` - Full path to the transcript file
- `{timestamp}` - ISO8601 timestamp when event occurred
- `{event}` - Either "shutdown" or "new_transcript"

### `on_transcript_start`
Triggered when a new transcript starts (Ctrl-N).

**Context variables**:
- `{transcript_file}` - Full path to the new transcript file
- `{timestamp}` - ISO8601 timestamp when event occurred

## Configuration Format

```yaml
hooks:
  on_transcript_end:
    - name: "Descriptive name for the hook"
      command: "shell command with {variable} substitution"
      enabled: true    # or false to disable
      async: true      # true = run in background, false = wait for completion
      timeout: 300     # optional: max seconds before terminating
```

## Example Use Cases

### 1. Summarize Meeting with Claude

```yaml
hooks:
  on_transcript_end:
    - name: "Claude Summarizer"
      command: "~/.pentecost/scripts/claude-summarize.sh {transcript_file}"
      enabled: true
      async: true
      timeout: 300
```

### 2. Backup Transcripts

```yaml
hooks:
  on_transcript_end:
    - name: "Backup to Dropbox"
      command: "cp {transcript_file} ~/Dropbox/meetings/"
      enabled: true
      async: true
```

### 3. Send Notifications

```yaml
hooks:
  on_transcript_end:
    - name: "Completion Notification"
      command: "osascript -e 'display notification \"Meeting ended\" with title \"Pentecost\"'"
      enabled: true
      async: true
```

### 4. Email Transcript

```yaml
hooks:
  on_transcript_end:
    - name: "Email Transcript"
      command: "mail -s 'Meeting Transcript' you@example.com < {transcript_file}"
      enabled: true
      async: true
```

### 5. Run Custom Analysis

```yaml
hooks:
  on_transcript_end:
    - name: "Custom Analysis"
      command: "python3 ~/scripts/analyze_meeting.py {transcript_file}"
      enabled: true
      async: true
      timeout: 600
```

### 6. Log to Database

```yaml
hooks:
  on_transcript_end:
    - name: "Log to Database"
      command: "curl -X POST https://api.example.com/meetings -d @{transcript_file}"
      enabled: true
      async: true
```

## Writing Custom Scripts

Create executable scripts in `~/.pentecost/scripts/` that accept the transcript file path as an argument:

```bash
#!/bin/bash
# ~/.pentecost/scripts/my-custom-hook.sh

TRANSCRIPT_FILE="$1"

# Your custom logic here
echo "Processing: $TRANSCRIPT_FILE"

# Example: Count words
wc -w "$TRANSCRIPT_FILE"

# Example: Extract action items
grep -i "action:" "$TRANSCRIPT_FILE" > "${TRANSCRIPT_FILE%.txt}_actions.txt"
```

Make it executable:
```bash
chmod +x ~/.pentecost/scripts/my-custom-hook.sh
```

Add to your hooks.yaml:
```yaml
hooks:
  on_transcript_end:
    - name: "My Custom Hook"
      command: "~/.pentecost/scripts/my-custom-hook.sh {transcript_file}"
      enabled: true
      async: true
```

## Hook Properties Explained

### `name`
Human-readable description of what the hook does. Displayed in logs.

### `command`
Shell command to execute. Use `{variable_name}` for context variable substitution.

The command runs through `/bin/bash -c`, so you can use:
- Shell pipes: `command1 | command2`
- Redirects: `command > output.txt`
- Conditionals: `[ -f file ] && command`
- Any bash features

### `enabled`
- `true`: Hook will execute
- `false`: Hook is skipped (useful for temporarily disabling)

### `async`
- `true`: Hook runs in background, doesn't block Pentecost
- `false`: Pentecost waits for hook to complete before continuing

**Recommendation**: Use `async: true` for most hooks, especially on shutdown.

### `timeout` (optional)
Maximum seconds the hook can run before being terminated.

- If not specified: Hook can run indefinitely
- If async: Runs in background with timeout protection
- If not async: Blocks for up to timeout seconds

**Recommendation**: Always set a timeout for long-running operations.

## Debugging Hooks

Pentecost displays hook execution status in the terminal:

```
🪝 Executing 2 hook(s) for event: on_transcript_end
  ▶️  Running hook: Claude Summarizer
  ✅ Hook 'Claude Summarizer' completed successfully
     Output: Summary saved to: transcript_2026-02-20_14-30-00_en-US_summary.md
  ▶️  Running hook: Backup to Dropbox
  ✅ Hook 'Backup to Dropbox' completed successfully
```

Error messages are also displayed:
```
  ❌ Hook 'My Script' failed with exit code 1
     Error: File not found: /path/to/transcript
```

### Testing Hooks

1. **Enable a simple test hook**:
   ```yaml
   hooks:
     on_transcript_end:
       - name: "Test Hook"
         command: "echo 'Hook triggered at {timestamp}' > ~/pentecost-test.txt"
         enabled: true
         async: false
   ```

2. **Run Pentecost and trigger event** (Ctrl-C to shutdown)

3. **Check output**:
   ```bash
   cat ~/pentecost-test.txt
   ```

## Advanced Examples

### Conditional Execution

```yaml
hooks:
  on_transcript_end:
    - name: "Summarize long meetings only"
      command: "[ $(wc -l < {transcript_file}) -gt 100 ] && ~/scripts/summarize.sh {transcript_file}"
      enabled: true
      async: true
```

### Chained Commands

```yaml
hooks:
  on_transcript_end:
    - name: "Process and Upload"
      command: "~/scripts/process.sh {transcript_file} && ~/scripts/upload.sh {transcript_file}"
      enabled: true
      async: true
```

### Using Environment Variables

```yaml
hooks:
  on_transcript_end:
    - name: "Upload to S3"
      command: "aws s3 cp {transcript_file} s3://$MEETING_BUCKET/transcripts/"
      enabled: true
      async: true
```

Set environment variable before running Pentecost:
```bash
export MEETING_BUCKET=my-meeting-bucket
./.build/debug/MultilingualRecognizer
```

## Troubleshooting

### Hook doesn't run
- Check `enabled: true` in hooks.yaml
- Verify hooks.yaml is at `~/.pentecost/hooks.yaml`
- Check Pentecost terminal output for hook messages

### Command not found
- Use full paths: `~/scripts/myscript.sh` or `/usr/local/bin/command`
- Check script is executable: `chmod +x script.sh`
- Test command manually: `/bin/bash -c "your command"`

### Script fails silently
- Set `async: false` to see errors immediately
- Add logging to your script: `echo "Debug: $VARIABLE" >> ~/debug.log`
- Check exit codes in your script: `set -e` to exit on errors

### Timeout too short
- Increase `timeout:` value
- Check if script needs more time for network/CPU intensive operations
- Remove timeout entirely for unlimited runtime (not recommended)

## Security Considerations

- **Input validation**: Scripts receive file paths from Pentecost - ensure they exist before processing
- **Command injection**: Variable substitution is safe, but be careful with custom scripts
- **File permissions**: Hooks run with your user privileges - protect sensitive scripts
- **Network operations**: Ensure timeouts for external API calls

## Next Steps

1. Review `hooks.yaml.example` for more examples
2. Check `scripts/claude-summarize.sh.example` for a complete script example
3. Create your own hooks based on your workflow needs
4. Share your useful hooks with the community!

## Contributing

Have a useful hook? Share it by:
1. Creating an example in `scripts/` directory
2. Documenting it in hooks.yaml.example
3. Submitting a pull request

## Support

For issues or questions about hooks:
- File an issue: https://github.com/dougbradbury/pentecost/issues
- Include your hooks.yaml configuration (redact sensitive info)
- Include hook output from Pentecost terminal
