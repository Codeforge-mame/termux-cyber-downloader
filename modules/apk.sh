#!/data/data/com.termux/files/usr/bin/bash
apk_menu() {
  banner "APK DOWNLOAD"
  printf " 1) Download from direct APK URL\n 2) APKPure via apkeep (unverified third-party source)\n 3) F-Droid via apkeep\n 0) Back\n"
  ask_choice "Choose: " a "1 2 3 0" || return 1
  case "$a" in
    1)
      local url name
      ask_url "Direct APK URL: " url || return 1
      ask "Output filename (e.g. app.apk): " name
      [[ "$name" == *.apk || "$name" == *.xapk ]] || name="${name:-download}.apk"
      mkdir -p "$APK_DIR"
      curl -fL --continue-at - "$url" -o "$APK_DIR/$name" && ok "Saved to $APK_DIR/$name"
      ;;
    2|3)
      require_cmd apkeep apkeep || return 1
      local query pkg src confirm rc html found
      ask "App name OR package ID (e.g. VLC, WhatsApp, or org.videolan.vlc): " query
      [ -n "$query" ] || { warn "No app name or package ID entered."; return 1; }

      case "${query,,}" in
        x|twitter) pkg=com.twitter.android ;;
        whatsapp) pkg=com.whatsapp ;;
        telegram) pkg=org.telegram.messenger ;;
        tiktok) pkg=com.zhiliaoapp.musically ;;
        instagram) pkg=com.instagram.android ;;
        facebook) pkg=com.facebook.katana ;;
        chrome|google\ chrome) pkg=com.android.chrome ;;
        vlc) pkg=org.videolan.vlc ;;
        spotify) pkg=com.spotify.music ;;
        sai) pkg=com.aefyr.sai.fdroid ;;
        *) pkg="$query" ;;
      esac

      if [[ ! "$pkg" =~ ^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$ ]]; then
        if [ "$a" = 3 ]; then
          err "F-Droid requires the exact package ID. Try a known name such as VLC, or enter its package ID."
          return 1
        fi
        info "Resolving '$query' through APKPure search..."
        html="$(curl -fsSL -A "Mozilla/5.0" --max-time 15 --get --data-urlencode "q=$query" "https://apkpure.com" 2>/dev/null)"
        found="$(printf '%s' "$html" | grep -oE '/[a-zA-Z0-9_-]+/[a-zA-Z0-9_]+\.[a-zA-Z0-9_.]+' | head -n 1 | cut -d'/' -f3)"
        if [[ "$found" =~ ^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$ ]]; then
          pkg="$found"
          ok "Matched package ID: $pkg"
        else
          err "Could not resolve that app name. Try its exact Android package ID."
          return 1
        fi
      fi

      mkdir -p "$APK_DIR"
      if [ "$a" = 2 ]; then
        warn "APKPure is a third-party source. Verify the publisher and APK signature before installing."
        ask "Continue anyway? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || return 0
        src=apk-pure
        apkeep -a "$pkg" -d "$src" -o 'acknowledge_dangers=true' "$APK_DIR"
        rc=$?
      else
        src=f-droid
        apkeep -a "$pkg" -d "$src" "$APK_DIR"
        rc=$?
        if [ "$rc" -ne 0 ]; then
          warn "Default F-Droid repository failed. Retrying with the Cloudflare F-Droid mirror..."
          apkeep -a "$pkg" -d "$src" -o 'repo=https://cloudflare.f-droid.org/repo' "$APK_DIR"
          rc=$?
        fi
      fi
      if [ "$rc" -eq 0 ]; then
        ok "apkeep finished. Check $APK_DIR for the downloaded package."
      else
        err "apkeep failed (exit code $rc). Check the package ID and try again later."
      fi
      return "$rc"
      ;;
    0|"") return 0 ;;
    *) warn "Unknown APK option."; return 1 ;;
  esac
}
