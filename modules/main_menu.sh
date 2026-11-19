#!/data/data/com.termux/files/usr/bin/bash
main_menu() {
  local url="$1" choice
  while true; do
    banner "TERMUX CYBER DOWNLOADER 2.0.1"
    printf " 1) Video download (resolution)\n 2) Turbo video (-N 8)\n 3) Trim video clip\n 4) Audio MP3\n 5) Telegram download (8 threads)\n 6) Sequential queue\n 7) APK downloader\n 8) Movie title search\n 9) Open legacy image / Android tools\n h) Help\n 0) Exit\n"
    ask "root@termux:~# " choice
    case "$choice" in
      1) video_download "$url" normal ;; 2) video_download "$url" turbo ;;
      3) trim_download "$url" ;; 4) audio_download "$url" ;;
      5) telegram_download "$url" ;; 6) queue_menu ;;
      7) apk_menu ;; 8) movie_search ;;
      9) bash "$CD_ROOT/legacy/termux-url-opener" "$url" ;;
      h|H) bash "$CD_ROOT/help_script" ;;
      0|q|Q) break ;;
      *) warn "Unknown selection." ;;
    esac
    printf "\n"; ask "Return to main menu? [Y/n]: " again
    [[ "$again" =~ ^[Nn]$ ]] && break
    url=""
  done
}
