#!/data/data/com.termux/files/usr/bin/bash
apk_menu() {
  banner "APK DOWNLOAD"
  printf " 1) Download from direct APK URL\n 2) APKPure via apkeep\n 3) F-Droid via apkeep\n 0) Back\n"
  ask "Choose: " a
  case "$a" in
    1)
      local url name
      ask "Direct APK URL: " url; valid_url "$url" || { err "Invalid URL."; return 1; }
      ask "Output filename (e.g. app.apk): " name
      [[ "$name" == *.apk || "$name" == *.xapk ]] || name="${name:-download}.apk"
      mkdir -p "$APK_DIR"; curl -fL --continue-at - "$url" -o "$APK_DIR/$name" && ok "Saved to $APK_DIR/$name"
      ;;
    2|3)
      require_cmd apkeep apkeep || return 1
      local pkg src; ask "Android package ID (e.g. org.videolan.vlc): " pkg
      src=apk-pure; [ "$a" = 3 ] && src=f-droid
      apkeep -a "$pkg" -d "$src" "$APK_DIR"
      ;;
  esac
}
