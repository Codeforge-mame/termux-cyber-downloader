#!/data/data/com.termux/files/usr/bin/bash

queue_add() {
  local url="${1:-}"
  [ -n "$url" ] || ask "URL to queue: " url
  valid_url "$url" || { err "Invalid URL."; return 1; }
  printf '%s\n' "$url" >> "$QUEUE_FILE" || { err "Could not write to queue file."; return 1; }
  ok "Added to sequential queue."
}

queue_edit() {
  local edit_file
  require_cmd nano nano || return 1

  # Edit a temporary copy so nano's save/exit flow cannot truncate the live queue.
  edit_file="$(mktemp "${QUEUE_FILE}.edit.XXXXXX")" || {
    err "Could not create a temporary queue file."
    return 1
  }
  cp "$QUEUE_FILE" "$edit_file" || {
    rm -f "$edit_file"
    err "Could not prepare the queue for editing."
    return 1
  }

  nano "$edit_file"
  local editor_rc=$?

  if [ "$editor_rc" -eq 0 ]; then
    if mv "$edit_file" "$QUEUE_FILE"; then
      ok "Queue changes saved."
    else
      err "Could not apply the edited queue. Your edited copy is at: $edit_file"
      return 1
    fi
  else
    rm -f "$edit_file"
    warn "Editor exited with an error. The original queue was kept unchanged."
    return "$editor_rc"
  fi
}

queue_run() {
  [ -s "$QUEUE_FILE" ] || { info "Queue is empty."; return 0; }

  local tmp="${QUEUE_FILE}.tmp" url rc failed=0 completed=0 total=0
  # Count queue entries before starting.
  total="$(grep -cve '^[[:space:]]*$' "$QUEUE_FILE" 2>/dev/null || printf '0')"
  : > "$tmp" || { err "Could not create the queue work file."; return 1; }

  info "Starting sequential queue: $total item(s). One URL will run at a time."

  # Use file descriptor 3 for queue input. Keeping stdin attached to the
  # terminal is essential because download functions ask interactive questions.
  while IFS= read -r url <&3 || [ -n "$url" ]; do
    [ -n "$url" ] || continue
    info "Queue item $((completed + failed + 1))/$total: $url"

    if [[ "$url" == *t.me/* ]]; then
      telegram_download "$url"
      rc=$?
    else
      video_download "$url" normal
      rc=$?
    fi

    if [ "$rc" -eq 0 ]; then
      completed=$((completed + 1))
    else
      printf '%s\n' "$url" >> "$tmp"
      failed=$((failed + 1))
      warn "This item failed or was cancelled; it will remain in the queue."
    fi
  done 3< "$QUEUE_FILE"

  if mv "$tmp" "$QUEUE_FILE"; then
    ok "Queue finished. Completed: $completed. Failed/remaining: $failed."
  else
    err "Could not update the queue file. Failed items are preserved in: $tmp"
    return 1
  fi
}

queue_menu() {
  local q confirm
  while true; do
    banner "SEQUENTIAL DOWNLOAD QUEUE"
    printf " 1) Add URL\n 2) Edit queue in nano\n 3) Show queue\n 4) Run queue\n 5) Clear queue\n 0) Back\n"
    ask_choice "Choose: " q "1 2 3 4 5 0" || { return 0; }
    case "$q" in
      1) queue_add ;;
      2) queue_edit ;;
      3)
        if [ -s "$QUEUE_FILE" ]; then cat -n "$QUEUE_FILE"
        else info "Queue is empty."
        fi
        ;;
      4) queue_run ;;
      5)
        if [ ! -s "$QUEUE_FILE" ]; then
          info "Queue is already empty."
        else
          ask "Clear all queued URLs? [y/N]: " confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            : > "$QUEUE_FILE" && ok "Queue cleared." || err "Could not clear the queue."
          else
            info "Queue was not changed."
          fi
        fi
        ;;
      0) return 0 ;;
      *) warn "Invalid selection."; continue ;;
    esac
    printf "\n"
  done
}
