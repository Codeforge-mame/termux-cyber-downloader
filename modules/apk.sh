#!/data/data/com.termux/files/usr/bin/bash
apk_menu() {
  banner "APK DOWNLOAD"
  printf " 1) Download from direct APK URL\n 2) APKPure via apkeep (unverified third-party source)\n 3) F-Droid via apkeep\n 0) Back\n"
  ask "Choose: " a
  case "$a" in
    1)
      local url name
      ask "Direct APK URL: " url; valid_url "$url" || { err "Invalid URL."; return 1; }
      ask "Output filename (e.g. app.apk): " name
      [[ "$name" == *.apk || "$name" == *.xapk ]] || name="${name:-download}.apk"
      mkdir -p "$APK_DIR"
      curl -fL --continue-at - "$url" -o "$APK_DIR/$name" && ok "Saved to $APK_DIR/$name"
      ;;
    2|3)
      require_cmd apkeep apkeep || return 1
      local pkg src confirm rc app_query search_url
      ask "App name OR package ID (e.g. VLC or org.videolan.vlc): " pkg
      [ -n "$pkg" ] || { warn "No app name or package ID entered."; return 1; }

      if [[ ! "$pkg" =~ ^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$ ]]; then
        app_query="$pkg"
        search_url="$(python3 -c 'import sys,urllib.parse; print("https://www.google.com/search?q="+urllib.parse.quote_plus(sys.argv[1]+" Android app package name"))' "$app_query" 2>/dev/null)"
        if [ -z "$search_url" ]; then
          err "Could not prepare app search URL. Install python with: pkg install python"
          return 1
        fi
        info "Searching for the app package ID: $app_query"
        if command -v termux-open-url >/dev/null 2>&1; then
          termux-open-url "$search_url" >/dev/null 2>&1
        else
          printf "Open this search in your browser: %s\n" "$search_url"
        fi
        ask "Enter the package ID shown in the search results: " pkg
        if [[ ! "$pkg" =~ ^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$ ]]; then
          err "That is not a valid Android package ID."
          return 1
        fi
      fi

      mkdir -p "$APK_DIR"
      if [ "$a" = 2 ]; then
        warn "APKPure is a third-party source and may distribute modified or unsafe APKs."
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
