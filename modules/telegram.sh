#!/data/data/com.termux/files/usr/bin/bash
telegram_download() {
  local url="$1" threads_choice threads rc res
  [ -n "$url" ] || ask "Telegram public link: " url
  [[ "$url" == *t.me/* ]] || { err "This does not look like a Telegram link."; return 1; }
  require_cmd tdl tdl || return 1

  banner "TELEGRAM DOWNLOAD THREADS"
  printf " 1) 1 thread (most conservative)\n 2) 2 threads\n 3) 4 threads\n 4) 8 threads (fastest option)\n 0) Cancel\n"
  ask "Choose thread count [default 8]: " threads_choice
  case "$threads_choice" in
    0) info "Telegram download cancelled."; return 0 ;;
    1) threads=1 ;;
    2) threads=2 ;;
    3) threads=4 ;;
    ""|4) threads=8 ;;
    *) warn "Invalid thread choice."; return 1 ;;
  esac

  info "Starting Telegram download with $threads thread(s)..."
  tdl dl -u "$url" -d "$VIDEO_DIR" -t "$threads" --continue
  rc=$?

  if [ "$rc" -ne 0 ]; then
    err "Telegram download did not complete (exit code $rc)."
    info "If it stalls, retry with fewer threads. Check that the channel is public and your tdl session can access the post."
    return "$rc"
  fi

  record_history telegram "$url"
  scan_media "$VIDEO_DIR"
  banner "OPTIONAL TELEGRAM VIDEO RESOLUTION"
  printf " 1) Keep original only\n 2) Create 1080p copy\n 3) Create 720p copy\n 4) Create 480p copy\n 5) Create 360p copy\n 0) Skip\n"
  ask "Choose: " res
  case "$res" in
    2) convert_telegram 1080p ;;
    3) convert_telegram 720p ;;
    4) convert_telegram 480p ;;
    5) convert_telegram 360p ;;
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
