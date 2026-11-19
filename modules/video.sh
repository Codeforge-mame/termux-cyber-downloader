#!/data/data/com.termux/files/usr/bin/bash
resolution_menu() {
  banner "VIDEO RESOLUTION"
  printf " 1) Best available\n 2) 2160p\n 3) 1440p\n 4) 1080p\n 5) 720p\n 6) 480p\n 7) 360p\n 0) Cancel\n"
  ask "Choose: " res_choice
  case "$res_choice" in
    1) FORMAT='bestvideo+bestaudio/best' ;;
    2) FORMAT='best[height<=2160]/bestvideo[height<=2160]+bestaudio/best[height<=2160]' ;;
    3) FORMAT='best[height<=1440]/bestvideo[height<=1440]+bestaudio/best[height<=1440]' ;;
    4) FORMAT='best[height<=1080]/bestvideo[height<=1080]+bestaudio/best[height<=1080]' ;;
    5) FORMAT='best[height<=720]/bestvideo[height<=720]+bestaudio/best[height<=720]' ;;
    6) FORMAT='best[height<=480]/bestvideo[height<=480]+bestaudio/best[height<=480]' ;;
    7) FORMAT='best[height<=360]/bestvideo[height<=360]+bestaudio/best[height<=360]' ;;
    *) return 1 ;;
  esac
}
video_download() {
  local url="$1" mode="$2" speed=2
  [ -n "$url" ] || ask "Video URL: " url
  valid_url "$url" || { err "Please provide a valid http(s) URL."; return 1; }
  resolution_menu || return 0
  [ "$mode" = turbo ] && speed=8
  info "Downloading with up to $speed parallel fragments where supported."
  run_ytdlp -4 -N "$speed" --continue --download-archive "$ARCHIVE_FILE" -f "$FORMAT" --merge-output-format mp4 -P "$VIDEO_DIR" -o "$OUT_TMPL" "$url"
  local rc=$?; [ "$rc" -eq 0 ] && record_history video "$url" && scan_media "$VIDEO_DIR"
  return "$rc"
}
trim_download() {
  local url="$1" start_t end_t
  [ -n "$url" ] || ask "Video URL: " url
  valid_url "$url" || { err "Please provide a valid http(s) URL."; return 1; }
  resolution_menu || return 0
  ask "Start time (HH:MM:SS): " start_t; ask "End time (HH:MM:SS): " end_t
  [[ "$start_t" =~ ^([0-9]{2}:)?[0-9]{2}:[0-9]{2}$ && "$end_t" =~ ^([0-9]{2}:)?[0-9]{2}:[0-9]{2}$ ]] || { err "Use HH:MM:SS timestamps."; return 1; }
  run_ytdlp -4 -N 2 --download-sections "*$start_t-$end_t" --force-keyframes-at-cuts --continue -f "$FORMAT" -P "$VIDEO_DIR" -o "%(title)s [clip].%(ext)s" "$url"
  local rc=$?; [ "$rc" -eq 0 ] && record_history trim "$url" && scan_media "$VIDEO_DIR"; return "$rc"
}
audio_download() {
  local url="$1"; [ -n "$url" ] || ask "Audio URL: " url
  valid_url "$url" || { err "Please provide a valid http(s) URL."; return 1; }
  run_ytdlp -4 -N 2 --download-archive "$AUDIO_ARCHIVE" -x --audio-format mp3 --embed-thumbnail -P "$MUSIC_DIR" -o "$OUT_TMPL" "$url"
  local rc=$?; [ "$rc" -eq 0 ] && record_history audio "$url" && scan_media "$MUSIC_DIR"; return "$rc"
}
