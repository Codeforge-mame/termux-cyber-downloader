#!/data/data/com.termux/files/usr/bin/bash
resolution_menu() {
  banner "VIDEO RESOLUTION"
  printf " 1) Best available\n 2) 2160p\n 3) 1440p\n 4) 1080p\n 5) 720p\n 6) 480p\n 7) 360p\n 0) Cancel\n"
  ask "Choose: " res_choice
  case "$res_choice" in
    1) FORMAT='bestvideo+bestaudio/best' ;;
    2) FORMAT='bestvideo[height<=2160]+bestaudio/best[height<=2160]/best' ;;
    3) FORMAT='bestvideo[height<=1440]+bestaudio/best[height<=1440]/best' ;;
    4) FORMAT='bestvideo[height<=1080]+bestaudio/best[height<=1080]/best' ;;
    5) FORMAT='bestvideo[height<=720]+bestaudio/best[height<=720]/best' ;;
    6) FORMAT='bestvideo[height<=480]+bestaudio/best[height<=480]/best' ;;
    7) FORMAT='bestvideo[height<=360]+bestaudio/best[height<=360]/best' ;;
    *) return 1 ;;
  esac
}
video_download() {
  local url="$1" mode="$2" speed=2
  [ -n "$url" ] || ask "Video URL: " url
  valid_url "$url" || { err "Please provide a valid http(s) URL."; return 1; }
  # Return non-zero on cancellation so queue mode keeps this URL for later.
  resolution_menu || return 1
  [ "$mode" = turbo ] && speed=8
  info "Downloading with up to $speed parallel fragments where supported."
  run_ytdlp -4 -N "$speed" --continue --download-archive "$ARCHIVE_FILE" -f "$FORMAT" --merge-output-format mp4 -P "$VIDEO_DIR" -o "$OUT_TMPL" "$url"
  local rc=$?; [ "$rc" -eq 0 ] && record_history video "$url" && scan_media "$VIDEO_DIR"
  return "$rc"
}
playlist_download() {
  local url="${1:-}" rc
  [ -n "$url" ] || ask "Playlist URL: " url
  valid_url "$url" || { err "Please enter a valid http(s) playlist URL."; return 1; }
  resolution_menu || return 1
  info "Downloading playlist into its own folder under $VIDEO_DIR."
  run_ytdlp -4 -N 2 --yes-playlist --continue --download-archive "$ARCHIVE_FILE" -f "$FORMAT" --merge-output-format mp4 -P "$VIDEO_DIR" -o "$OUT_TMPL" "$url"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    record_history playlist "$url"
    scan_media "$VIDEO_DIR"
    ok "Playlist download finished."
  fi
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


video_subtitle_download() {
  local url="${1:-}" choice format rc subtitle_dir="$VIDEO_DIR/Subtitles"
  [ -n "$url" ] || ask "Video URL: " url
  valid_url "$url" || { err "Please provide a valid http(s) URL."; return 1; }
  banner "VIDEO WITH SUBTITLES"
  printf " 1) Best available + English subtitles\n 2) 720p + English subtitles\n 3) 480p + English subtitles\n 4) 360p + English subtitles\n 0) Cancel\n"
  ask "Choose: " choice
  case "$choice" in
    1) format='bestvideo+bestaudio/best' ;;
    2) format='bestvideo[height<=720]+bestaudio/best[height<=720]/best' ;;
    3) format='bestvideo[height<=480]+bestaudio/best[height<=480]/best' ;;
    4) format='bestvideo[height<=360]+bestaudio/best[height<=360]/best' ;;
    *) return 1 ;;
  esac
  mkdir -p "$subtitle_dir"
  run_ytdlp -4 -N 2 --sleep-interval 2 --max-sleep-interval 5 --download-archive "$HOME/.yt-dlp-subtitles-archive.txt" --write-subs --write-auto-subs --sub-langs "en.*,en" --embed-subs -f "$format" --merge-output-format mp4 -P "$subtitle_dir" -o "$OUT_TMPL" "$url"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    record_history video_subtitles "$url"
    scan_media "$subtitle_dir"
  fi
  return "$rc"
}

video_only_download() {
  local url="${1:-}" rc video_only_dir="$VIDEO_DIR/VideoOnly"
  [ -n "$url" ] || ask "Video URL (video stream without audio): " url
  valid_url "$url" || { err "Please provide a valid http(s) URL."; return 1; }
  info "Downloading video-only stream (no audio track)."
  mkdir -p "$video_only_dir"
  run_ytdlp -4 -N 2 --download-archive "$HOME/.yt-dlp-video-only-archive.txt" -f 'bestvideo[ext=mp4]/bestvideo' -P "$video_only_dir" -o "$OUT_TMPL" "$url"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    record_history video_only "$url"
    scan_media "$video_only_dir"
  fi
  return "$rc"
}

video_extras_menu() {
  local url="${1:-}" choice
  while true; do
    banner "VIDEO EXTRAS"
    printf " 1) Download video with English subtitles\n 2) Download video only (no audio)\n 0) Back\n"
    ask "Choose: " choice
    case "$choice" in
      1) video_subtitle_download "$url"; url="" ;;
      2) video_only_download "$url"; url="" ;;
      0|"") return 0 ;;
      *) warn "Unknown video option." ;;
    esac
    printf "\n"
  done
}
