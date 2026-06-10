#!/bin/bash
# designlens Stop hook — merges session stats into .metadata.json in the current stage dir.
# Fires at the end of each Claude Code agent turn. Must never cause the agent turn to fail.

set -euo pipefail

HASH=$(echo "$PWD" | md5sum | cut -c1-8)
TEMP_FILE="/tmp/designlens-$HASH.json"
SESSION_FILE="/tmp/designlens-sess-$HASH.json"

main() {
  local payload
  payload=$(cat)

  local session_id
  session_id=$(echo "$payload" | jq -r '.session_id // ""' 2>/dev/null) || session_id=""

  # Read session file for model and transcript offset (written by SessionStart hook)
  local model="unknown" transcript_offset=0
  if [[ -f "$SESSION_FILE" ]]; then
    model=$(jq -r '.model // "unknown"' "$SESSION_FILE" 2>/dev/null) || model="unknown"
    transcript_offset=$(jq -r '.transcript_offset // 0' "$SESSION_FILE" 2>/dev/null) || transcript_offset=0
  fi

  # Read transcript JSONL for tokens and user words — only new lines since last turn
  local input_tokens=null output_tokens=null user_word_count=null new_offset
  local transcript_path
  transcript_path=$(echo "$payload" | jq -r '.transcript_path // ""' 2>/dev/null) || transcript_path=""
  transcript_path="${transcript_path/#\~/$HOME}"
  new_offset=$transcript_offset

  if [[ -f "$transcript_path" ]]; then
    new_offset=$(wc -l < "$transcript_path" 2>/dev/null | tr -d ' ') || new_offset=$transcript_offset
    local new_lines
    new_lines=$(tail -n +"$((transcript_offset + 1))" "$transcript_path" 2>/dev/null) || new_lines=""

    if [[ -n "$new_lines" ]]; then
      # Sum input tokens from new assistant messages (including cache read/write tokens)
      local it
      it=$(echo "$new_lines" | jq -r 'select(.message.role == "assistant") | (.message.usage.input_tokens // 0) + (.message.usage.cache_read_input_tokens // 0) + (.message.usage.cache_creation_input_tokens // 0)' 2>/dev/null \
        | awk '{s+=$1} END {if (NR>0) print s; else print "null"}') || it="null"
      [[ "$it" =~ ^[0-9]+$ ]] && input_tokens=$it

      # Sum output tokens from new assistant messages
      local ot
      ot=$(echo "$new_lines" | jq -r 'select(.message.role == "assistant") | .message.usage.output_tokens // 0' 2>/dev/null \
        | awk '{s+=$1} END {if (NR>0) print s; else print "null"}') || ot="null"
      [[ "$ot" =~ ^[0-9]+$ ]] && output_tokens=$ot

      # Count words from new user messages
      local wc_val
      wc_val=$(echo "$new_lines" | jq -r '
        select(.message.role == "user") |
        .message.content |
        if type == "string" then .
        elif type == "array" then map(select(.type == "text") | .text // "") | join(" ")
        else "" end
      ' 2>/dev/null | wc -w | tr -d ' ') || wc_val="null"
      [[ "$wc_val" =~ ^[0-9]+$ ]] && user_word_count=$wc_val
    fi
  fi

  # Update transcript offset in session file
  if [[ -f "$SESSION_FILE" ]]; then
    local tmp_sess
    tmp_sess=$(jq --argjson o "$new_offset" '.transcript_offset = $o' "$SESSION_FILE" 2>/dev/null) || tmp_sess=""
    [[ -n "$tmp_sess" ]] && echo "$tmp_sess" > "$SESSION_FILE" || true
  fi

  # Read temp file for per-turn line/file stats
  local lines_added=null lines_deleted=null files_changed=null
  if [[ -f "$TEMP_FILE" ]]; then
    lines_added=$(jq -r '.lines_added // "null"' "$TEMP_FILE" 2>/dev/null) || lines_added="null"
    lines_deleted=$(jq -r '.lines_deleted // "null"' "$TEMP_FILE" 2>/dev/null) || lines_deleted="null"
    files_changed=$(jq -r '.file_paths | if type == "array" then length else "null" end' "$TEMP_FILE" 2>/dev/null) || files_changed="null"
  fi

  # Find current stage directory
  local stage_dir
  stage_dir=$(ls -d specs/[0-9][0-9][0-9]-*/ 2>/dev/null | sort | tail -1) || stage_dir=""
  [[ -n "$stage_dir" && -d "$stage_dir" ]] || return 0

  local metadata_file="${stage_dir}.metadata.json"

  # Read existing metadata
  local ex_input=null ex_output=null ex_words=null ex_added=null ex_deleted=null ex_files=null
  local ex_sessions=0 ex_agents="[]" ex_created="" ex_last_session_id=""
  if [[ -f "$metadata_file" ]]; then
    ex_input=$(jq -r '.input_tokens // "null"' "$metadata_file" 2>/dev/null) || ex_input="null"
    ex_output=$(jq -r '.output_tokens // "null"' "$metadata_file" 2>/dev/null) || ex_output="null"
    ex_words=$(jq -r '.user_word_count // "null"' "$metadata_file" 2>/dev/null) || ex_words="null"
    ex_added=$(jq -r '.lines_added // "null"' "$metadata_file" 2>/dev/null) || ex_added="null"
    ex_deleted=$(jq -r '.lines_deleted // "null"' "$metadata_file" 2>/dev/null) || ex_deleted="null"
    ex_files=$(jq -r '.files_changed // "null"' "$metadata_file" 2>/dev/null) || ex_files="null"
    ex_sessions=$(jq -r '.sessions // 0' "$metadata_file" 2>/dev/null) || ex_sessions=0
    ex_agents=$(jq -r '.agents // []' "$metadata_file" 2>/dev/null) || ex_agents="[]"
    ex_created=$(jq -r '.created // ""' "$metadata_file" 2>/dev/null) || ex_created=""
    ex_last_session_id=$(jq -r '.last_session_id // ""' "$metadata_file" 2>/dev/null) || ex_last_session_id=""
  fi

  # Sum helper: null + null = null; null + N = N; N + M = N+M
  sum() {
    local a="$1" b="$2"
    if [[ "$a" == "null" && "$b" == "null" ]]; then echo "null"
    elif [[ "$a" == "null" ]]; then echo "$b"
    elif [[ "$b" == "null" ]]; then echo "$a"
    else echo $(( a + b ))
    fi
  }

  # Increment sessions only when session_id changes (new user session, not a new turn)
  local new_sessions
  if [[ -n "$session_id" && "$session_id" != "$ex_last_session_id" ]]; then
    new_sessions=$(( ex_sessions + 1 ))
  else
    new_sessions=$ex_sessions
  fi

  local new_input new_output new_words new_added new_deleted new_files new_agents
  new_input=$(sum "$ex_input" "$input_tokens")
  new_output=$(sum "$ex_output" "$output_tokens")
  new_words=$(sum "$ex_words" "$user_word_count")
  new_added=$(sum "$ex_added" "$lines_added")
  new_deleted=$(sum "$ex_deleted" "$lines_deleted")
  new_files=$(sum "$ex_files" "$files_changed")
  new_agents=$(echo "$ex_agents" | jq --arg a "$model" 'if index($a) then . else . + [$a] end' 2>/dev/null) || new_agents="[\"$model\"]"

  local last_updated created
  last_updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  created="${ex_created:-$last_updated}"
  local last_session_id="${session_id:-$ex_last_session_id}"

  jq -n \
    --argjson agents "$new_agents" \
    --arg created "$created" \
    --arg last_updated "$last_updated" \
    --arg last_session_id "$last_session_id" \
    --argjson sessions "$new_sessions" \
    --argjson input_tokens "$([ "$new_input" = "null" ] && echo "null" || echo "$new_input")" \
    --argjson output_tokens "$([ "$new_output" = "null" ] && echo "null" || echo "$new_output")" \
    --argjson user_word_count "$([ "$new_words" = "null" ] && echo "null" || echo "$new_words")" \
    --argjson lines_added "$([ "$new_added" = "null" ] && echo "null" || echo "$new_added")" \
    --argjson lines_deleted "$([ "$new_deleted" = "null" ] && echo "null" || echo "$new_deleted")" \
    --argjson files_changed "$([ "$new_files" = "null" ] && echo "null" || echo "$new_files")" \
    '{
      agents: $agents,
      created: $created,
      last_updated: $last_updated,
      last_session_id: $last_session_id,
      sessions: $sessions,
      input_tokens: $input_tokens,
      output_tokens: $output_tokens,
      user_word_count: $user_word_count,
      lines_added: $lines_added,
      lines_deleted: $lines_deleted,
      files_changed: $files_changed
    }' > "$metadata_file" 2>/dev/null || true

  # Clean up per-turn temp file (session file persists until next SessionStart)
  rm -f "$TEMP_FILE" 2>/dev/null || true
}

main 2>/dev/null || true
