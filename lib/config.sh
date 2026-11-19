#!/data/data/com.termux/files/usr/bin/bash
CD_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CD_HOME="$HOME"
VIDEO_DIR="$HOME/storage/movies"; MUSIC_DIR="$HOME/storage/music"; PIC_DIR="$HOME/storage/pictures"
DOC_DIR="$HOME/storage/shared/Documents"; APK_DIR="$DOC_DIR/APKs"
ARCHIVE_FILE="$HOME/.yt-dlp-archive.txt"; AUDIO_ARCHIVE="$HOME/.yt-dlp-audio-archive.txt"
QUEUE_FILE="$CD_ROOT/data/download_queue.txt"; HISTORY_FILE="$CD_ROOT/data/download_history.txt"
OUT_TMPL='%(playlist_title&{}/|)s%(playlist_index&{} - |)s%(title)s.%(ext)s'
mkdir -p "$VIDEO_DIR" "$MUSIC_DIR" "$PIC_DIR" "$DOC_DIR" "$APK_DIR" "$CD_ROOT/data" "$CD_ROOT/config"
touch "$QUEUE_FILE" "$HISTORY_FILE"
