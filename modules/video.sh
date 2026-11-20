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
  resolution_menu || return 1
  [ "$mode" = turbo ] && speed=8
  info "Downloading with up to $speed parallel fragments where supported."
  run_ytdlp -4 -N "$speed" --continue --download-archive "$ARCHIVE_FILE" -f "$FORMAT" --merge-output-format mp4 -P "$VIDEO_DIR" -o "$OUT_TMPL" "$url"
  local rc=$?; [ "$rc" -eq 0 ] && record_history video "$url" && scan_media "$VIDEO_DIR"
  return "$rc"
}
playlist_download() {
  local url="${1:-}" folder_name playlist_dir rc
  [ -n "$url" ] || ask "Playlist URL: " url
  valid_url "$url" || { err "Please enter a valid http(s) playlist URL."; return 1; }
  ask "Folder name for this playlist (inside Movies): " folder_name
  folder_name="$(printf '%s' "$folder_name" | tr -cd '[:alnum:] _.-' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | cut -c1-80)"
  case "$folder_name" in
    ""|"."|"..") err "Please enter a valid folder name."; return 1 ;;
  esac
  resolution_menu || return 1
  playlist_dir="$VIDEO_DIR/$folder_name"
  mkdir -p "$playlist_dir" || { err "Could not create playlist folder: $playlist_dir"; return 1; }
  info "Playlist will be saved in: $playlist_dir"
  run_ytdlp -4 -N 2 --yes-playlist --continue --download-archive "$ARCHIVE_FILE" -f "$FORMAT" --merge-output-format mp4 -P "$playlist_dir" -o "%(playlist_index)03d - %(title)s.%(ext)s" "$url"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    record_history playlist "$url"
    scan_media "$playlist_dir"
    ok "Playlist download finished. Folder: $folder_name"
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
  banner "VIDEO + ENGLISH SUBTITLES"
  printf " 1) Best available + English subtitles\n 2) 720p + English subtitles\n 3) 480p + English subtitles\n 4) 360p + English subtitles\n 0) Cancel\n"
  ask "Choose: " choice
  case "$choice" in
    1) format='bv+ba/b' ;;
    2) format='bv[height<=720]+ba/b[height<=720]/b' ;;
    3) format='bv[height<=480]+ba/b[height<=480]/b' ;;
    4) format='bv[height<=360]+ba/b[height<=360]/b' ;;
    *) return 1 ;;
  esac
  mkdir -p "$subtitle_dir" || { err "Could not create subtitle download folder."; return 1; }
  info "Downloading the video and English subtitles together..."
  info "The video will be saved in: $subtitle_dir"
  run_ytdlp --ignore-config --no-simulate -4 -N 2 \
    --sleep-interval 2 --max-sleep-interval 5 \
    --write-subs --write-auto-subs --sub-langs "en.*,en" \
    --convert-subs srt --embed-subs --embed-metadata \
    -f "$format" --merge-output-format mp4 --remux-video mp4 \
    -P "$subtitle_dir" -o "$OUT_TMPL" "$url"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    record_history video_subtitles "$url"
    scan_media "$subtitle_dir"
    ok "Video download completed. English subtitles were embedded when available."
  else
    err "Video + subtitle download failed (exit code $rc). Check whether this source provides a downloadable video and English subtitles."
  fi
  return "$rc"
}

video_only_download() {
  local url="${1:-}" rc choice format archive_tag video_only_dir="$VIDEO_DIR/VideoOnly"
  [ -n "$url" ] || ask "Video URL (video stream without audio): " url
  valid_url "$url" || { err "Please provide a valid http(s) URL."; return 1; }
  banner "VIDEO-ONLY RESOLUTION"
  printf " 1) Best available\n 2) Up to 2160p\n 3) Up to 1440p\n 4) Up to 1080p\n 5) Up to 720p\n 6) Up to 480p\n 7) Up to 360p\n 0) Cancel\n"
  ask "Choose: " choice
  case "$choice" in
    1) format='bestvideo/best'; archive_tag="best" ;;
    2) format='bestvideo[height<=2160]/bestvideo'; archive_tag="2160p" ;;
    3) format='bestvideo[height<=1440]/bestvideo'; archive_tag="1440p" ;;
    4) format='bestvideo[height<=1080]/bestvideo'; archive_tag="1080p" ;;
    5) format='bestvideo[height<=720]/bestvideo'; archive_tag="720p" ;;
    6) format='bestvideo[height<=480]/bestvideo'; archive_tag="480p" ;;
    7) format='bestvideo[height<=360]/bestvideo'; archive_tag="360p" ;;
    *) return 1 ;;
  esac
  mkdir -p "$video_only_dir" || { err "Could not create video-only folder."; return 1; }
  info "Downloading video-only stream (no audio track)."
  run_ytdlp -4 -N 2 --continue --download-archive "$HOME/.yt-dlp-video-only-$archive_tag-archive.txt" -f "$format" -P "$video_only_dir" -o "$OUT_TMPL" "$url"
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
    printf " 1) Download video with English subtitles\n 2) Download video only (choose resolution, no audio)\n 0) Back\n"
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
