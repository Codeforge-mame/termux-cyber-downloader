#!/data/data/com.termux/files/usr/bin/bash
main_menu() {
  local url="$1" choice again
  while true; do
    banner "CYBERFORGE TOOLKIT 2.1"
    printf '%s\n' \
      " 1) Video download" \
      " 2) Turbo video" \
      " 3) Trim video" \
      " 4) Audio MP3" \
      " 5) Telegram download" \
      " 6) Sequential queue" \
      " 7) APK downloader" \
      " 8) Movie search" \
      " 9) Playlist download" \
      "10) Image & media tools" \
      "11) Video + subtitles" \
      "12) Document Manager" \
      "13) 4G network settings" \
      "14) Tool update center" \
      " h) Help" \
      " 0) Exit"
    ask "cyberforge> " choice
    case "$choice" in
      1) video_download "$url" normal ;;
      2) video_download "$url" turbo ;;
      3) trim_download "$url" ;;
      4) audio_download "$url" ;;
      5) telegram_download "$url" ;;
      6) queue_menu ;;
      7) apk_menu ;;
      8) movie_search ;;
      9) playlist_download "$url" ;;
      10) image_menu "$url" ;;
      11) video_extras_menu "$url" ;;
      12) document_manager_menu ;;
      13) open_4g_network_settings ;;
      14) tools_update_menu ;;
      h|H) bash "$CD_ROOT/help_script" ;;
      0|q|Q) break ;;
      *) warn "Unknown selection." ;;
    esac
    printf '\n'
    ask "Return to main menu? [Y/n]: " again
    [[ "$again" =~ ^[Nn]$ ]] && break
    url=""
  done
}
