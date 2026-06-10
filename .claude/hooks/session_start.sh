#!/bin/bash
# designlens SessionStart hook — records model and session ID to a per-session temp file.
# Fires once at the start of each Claude Code session. Must never cause the session to fail.

set -euo pipefail

HASH=$(echo "$PWD" | md5sum | cut -c1-8)
SESSION_FILE="/tmp/designlens-sess-$HASH.json"

main() {
  local payload
  payload=$(cat)

  local model session_id
  model=$(echo "$payload" | jq -r '.model // "unknown"' 2>/dev/null) || model="unknown"
  session_id=$(echo "$payload" | jq -r '.session_id // ""' 2>/dev/null) || session_id=""

  jq -n \
    --arg model "$model" \
    --arg session_id "$session_id" \
    --argjson transcript_offset 0 \
    '{model: $model, session_id: $session_id, transcript_offset: $transcript_offset}' \
    > "$SESSION_FILE" 2>/dev/null || true
}

main 2>/dev/null || true
