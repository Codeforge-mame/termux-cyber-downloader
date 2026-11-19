#!/data/data/com.termux/files/usr/bin/bash
telegram_download() {
  local url="$1" file res rc
  [ -n "$url" ] || ask "Telegram public link: " url
  [[ "$url" == *t.me/* ]] || { err "This does not look like a Telegram link."; return 1; }
  require_cmd tdl tdl || return 1
  info "Starting Telegram download with 8 threads..."
  tdl dl -u "$url" -d "$VIDEO_DIR" -t 8 --continue
  rc=$?

  if [ "$rc" -eq 130 ]; then
    warn "The download was interrupted. If it was stuck at 0 B, tdl may be hanging while reading the Telegram message."
    ask "Retry this link with 1 thread? [Y/n]: " res
    if [[ ! "$res" =~ ^[Nn]$ ]]; then
      info "Retrying Telegram download with 1 thread..."
      tdl dl -u "$url" -d "$VIDEO_DIR" -t 1 --continue
      rc=$?
    fi
  fi

  if [ "$rc" -ne 0 ]; then
    err "Telegram download did not complete (exit code $rc)."
    info "Check that the channel is public and the Telegram account configured in tdl can access the post."
    info "If it repeatedly stays at 0 B, send the output of: tdl version"
    return "$rc"
  fi

  record_history telegram "$url"; scan_media "$VIDEO_DIR"
  banner "OPTIONAL TELEGRAM CONVERSION"
  printf " 1) Keep original only\n 2) Create 1080p copy\n 3) Create 720p copy\n 4) Create 480p copy\n 5) Create 360p copy\n 0) Skip\n"
  ask "Choose: " res
  case "$res" in
    2) convert_telegram 1080p ;; 3) convert_telegram 720p ;; 4) convert_telegram 480p ;; 5) convert_telegram 360p ;;
    *) info "Original Telegram download retained." ;;
  esac
}
convert_telegram() {
  require_cmd ffmpeg ffmpeg || return 1
  local height="$1" src out
  ask "Path to downloaded video (inside $VIDEO_DIR): " src
  [ -f "$src" ] || { err "File not found."; return 1; }
  out="${src%.*}_${height}.mp4"
  [ ! -e "$out" ] || { err "Output already exists: $out"; return 1; }
  ffmpeg -i "$src" -vf "scale=-2:min($height\\,ih)" -c:v libx264 -preset veryfast -crf 23 -c:a aac "$out"
  [ $? -eq 0 ] && ok "Converted copy saved: $out"
}
