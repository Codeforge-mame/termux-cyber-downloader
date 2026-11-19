#!/data/data/com.termux/files/usr/bin/bash
require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; info "Install it with: pkg install $2"; return 1; }; }
record_history() { printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" >> "$HISTORY_FILE"; }
scan_media() { command -v termux-media-scan >/dev/null 2>&1 && termux-media-scan -r "$1" >/dev/null 2>&1 || true; }
notify_done() { command -v termux-notification >/dev/null 2>&1 && termux-notification --title "Termux Cyber Toolkit" --content "$1" >/dev/null 2>&1 || true; }
run_ytdlp() {
  require_cmd yt-dlp yt-dlp || return 1
  yt-dlp "$@"; local rc=$?
  if [ "$rc" -ne 0 ]; then
    warn "Download exited with code $rc. yt-dlp can resume partial downloads when run again."
    ask "Retry? [y/N]: " retry
    [[ "$retry" =~ ^[Yy]$ ]] && yt-dlp "$@"
  fi
  return $?
}
valid_url() { [[ "$1" =~ ^https?:// ]]; }
