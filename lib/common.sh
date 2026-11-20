#!/data/data/com.termux/files/usr/bin/bash
require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; info "Install it with: pkg install $2"; return 1; }; }
record_history() { printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$HISTORY_FILE"; }
scan_media() { command -v termux-media-scan >/dev/null 2>&1 && termux-media-scan -r "$1" >/dev/null 2>&1 || true; }
notify_done() { command -v termux-notification >/dev/null 2>&1 && termux-notification --title "Termux Cyber Toolkit" --content "$1" >/dev/null 2>&1 || true; }

# YouTube 429 recovery: detect the actual rate-limit response, let the user
# refresh the mobile IP, then rerun the exact same yt-dlp command.
run_ytdlp() {
  require_cmd yt-dlp yt-dlp || return 1
  local log_file rc retry
  while true; do
    log_file="$(mktemp)" || { err "Could not create yt-dlp log."; return 1; }
    yt-dlp --sleep-requests 1 --sleep-interval 3 --max-sleep-interval 8 "$@" 2>&1 | tee "$log_file"
    rc=${PIPESTATUS[0]}

    if grep -Eiq 'HTTP Error 429|Too Many Requests|429:|rate.?limit' "$log_file"; then
      rm -f "$log_file"
      banner "YOUTUBE 429 RATE LIMIT"
      warn "YouTube is temporarily rate-limiting this connection."
      info "1) Turn Airplane Mode ON for about 10 seconds."
      info "2) Turn Airplane Mode OFF and wait for mobile data to reconnect."
      info "3) Return here and press Enter to retry the same download."
      command -v termux-notification >/dev/null 2>&1 && termux-notification --title "YouTube 429 rate limit" --content "Toggle Airplane Mode for 10 seconds, then return to Termux and retry." --sound
      ask "Press Enter after reconnecting, or type q to stop: " retry
      if [[ "$retry" =~ ^[Qq]$ ]]; then
        warn "Download stopped by user. Partial yt-dlp files are retained for a later retry."
        return "$rc"
      fi
      info "Retrying the same download command..."
      continue
    fi

    rm -f "$log_file"
    if [ "$rc" -ne 0 ]; then
      warn "yt-dlp exited with code $rc."
    fi
    return "$rc"
  done
}
valid_url() { [[ "$1" =~ ^https?:// ]]; }
