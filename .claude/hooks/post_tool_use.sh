#!/bin/bash
# designlens PostToolUse hook — accumulates line and file stats to a temp file.
# Fires after every Claude Code tool call. Must never cause the agent turn to fail.

set -euo pipefail

TEMP_FILE="/tmp/designlens-$(echo "$PWD" | md5sum | cut -c1-8).json"

main() {
  local payload
  payload=$(cat)

  local tool_name
  tool_name=$(echo "$payload" | jq -r '.tool_name // empty' 2>/dev/null) || return 0

  if [[ "$tool_name" != "Write" && "$tool_name" != "Edit" ]]; then
    return 0
  fi

  local file_path lines_added lines_deleted
  file_path=$(echo "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || return 0

  if [[ "$tool_name" == "Write" ]]; then
    local content
    content=$(echo "$payload" | jq -r '.tool_input.content // empty' 2>/dev/null) || return 0
    lines_added=$(echo "$content" | wc -l)
    lines_deleted=0
  else
    local old_string new_string
    old_string=$(echo "$payload" | jq -r '.tool_input.old_string // empty' 2>/dev/null) || return 0
    new_string=$(echo "$payload" | jq -r '.tool_input.new_string // empty' 2>/dev/null) || return 0
    lines_added=$(echo "$new_string" | wc -l)
    lines_deleted=$(echo "$old_string" | wc -l)
  fi

  # Read existing temp file or start fresh
  local existing_added=0 existing_deleted=0 existing_files="[]"
  if [[ -f "$TEMP_FILE" ]]; then
    existing_added=$(jq -r '.lines_added // 0' "$TEMP_FILE" 2>/dev/null) || existing_added=0
    existing_deleted=$(jq -r '.lines_deleted // 0' "$TEMP_FILE" 2>/dev/null) || existing_deleted=0
    existing_files=$(jq -r '.file_paths // []' "$TEMP_FILE" 2>/dev/null) || existing_files="[]"
  fi

  local new_added new_deleted new_files
  new_added=$(( existing_added + lines_added ))
  new_deleted=$(( existing_deleted + lines_deleted ))

  # Add file_path to array if not already present
  if [[ -n "$file_path" ]]; then
    new_files=$(echo "$existing_files" | jq --arg fp "$file_path" 'if index($fp) then . else . + [$fp] end' 2>/dev/null) || new_files="$existing_files"
  else
    new_files="$existing_files"
  fi

  jq -n \
    --argjson added "$new_added" \
    --argjson deleted "$new_deleted" \
    --argjson files "$new_files" \
    '{lines_added: $added, lines_deleted: $deleted, file_paths: $files}' \
    > "$TEMP_FILE" 2>/dev/null || true
}

main 2>/dev/null || true
