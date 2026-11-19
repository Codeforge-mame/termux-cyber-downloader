#!/data/data/com.termux/files/usr/bin/bash
queue_add() {
  local url="$1"; [ -n "$url" ] || ask "URL to queue: " url
  valid_url "$url" || { err "Invalid URL."; return 1; }
  printf '%s\n' "$url" >> "$QUEUE_FILE"; ok "Added to sequential queue."
}
queue_run() {
  [ -s "$QUEUE_FILE" ] || { info "Queue is empty."; return 0; }
  local tmp="$QUEUE_FILE.tmp" url failed=0
  : > "$tmp"
  while IFS= read -r url || [ -n "$url" ]; do
    [ -n "$url" ] || continue
    info "Queue item: $url"
    if [[ "$url" == *t.me/* ]]; then telegram_download "$url"
    else video_download "$url" normal
    fi
    if [ $? -ne 0 ]; then printf '%s\n' "$url" >> "$tmp"; failed=$((failed+1)); fi
  done < "$QUEUE_FILE"
  mv "$tmp" "$QUEUE_FILE"
  ok "Queue finished. Failed items retained: $failed"
}
queue_menu() {
  banner "SEQUENTIAL DOWNLOAD QUEUE"
  printf " 1) Add URL\n 2) Edit queue in nano\n 3) Show queue\n 4) Run queue\n 5) Clear queue\n 0) Back\n"
  ask "Choose: " q
  case "$q" in
    1) queue_add ;; 2) require_cmd nano nano && nano "$QUEUE_FILE" ;;
    3) cat -n "$QUEUE_FILE" ;; 4) queue_run ;;
    5) ask "Clear all queued URLs? [y/N]: " confirm; [[ "$confirm" =~ ^[Yy]$ ]] && : > "$QUEUE_FILE" ;;
  esac
}
