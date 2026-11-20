#!/data/data/com.termux/files/usr/bin/bash

document_download() {
  local url="${1:-}" clean ext target_dir rc
  [ -n "$url" ] || ask "Document or archive URL: " url
  valid_url "$url" || { err "Please enter a valid http(s) URL."; return 1; }
  clean="${url%%\?*}"
  ext="${clean##*.}"
  ext="${ext,,}"
  case "$ext" in
    apk|xapk) target_dir="$APK_DIR" ;;
    pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|7z|epub|txt|csv) target_dir="$DOC_DIR" ;;
    *) err "Unsupported document/file extension: $ext"; return 1 ;;
  esac
  mkdir -p "$target_dir"
  info "Saving .$ext file to $target_dir"
  curl -fL --retry 2 --continue-at - -A "Mozilla/5.0" -J -O --output-dir "$target_dir" "$url"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "File download finished. Check $target_dir"
    scan_media "$target_dir"
    record_history document "$url"
  else
    err "File download failed (exit code $rc)."
  fi
  return "$rc"
}

open_4g_network_settings() {
  if ! command -v am >/dev/null 2>&1; then
    err "Android activity manager (am) is unavailable."
    return 1
  fi
  info "Opening Android's testing / radio information screen."
  info "Choose LTE only for a 4G lock. Restore Auto or LTE/WCDMA if calls or mobile service stop working."
  am start -n com.android.phone/.settings.RadioInfo
}
