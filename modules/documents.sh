#!/data/data/com.termux/files/usr/bin/bash

document_download() {
  local url="${1:-}" clean ext target_dir rc filename output_file
  [ -n "$url" ] || ask_url "Document or archive URL: " url || return 1
  valid_url "$url" || { err "Please enter a valid http(s) URL."; return 1; }
  clean="${url%%\?*}"
  ext="${clean##*.}"
  ext="${ext,,}"
  case "$ext" in
    apk|xapk) target_dir="$APK_DIR" ;;
    pdf|doc|docx|xls|xlsx|ppt|pptx|zip|rar|7z|epub|txt|csv) target_dir="$DOC_DIR" ;;
    *) err "Unsupported document/file extension: $ext"; return 1 ;;
  esac

  # -J/--remote-header-name cannot be combined with --continue-at.
  # Use a stable URL-derived filename so curl can resume into the same file.
  filename="${clean##*/}"
  filename="$(printf '%s' "$filename" | tr -cd '[:alnum:] ._()-' | cut -c1-180)"
  [ -n "$filename" ] || filename="download.$ext"
  case "$filename" in
    *."$ext") ;;
    *) filename="$filename.$ext" ;;
  esac
  output_file="$target_dir/$filename"

  mkdir -p "$target_dir" || { err "Could not create destination folder: $target_dir"; return 1; }
  info "Saving .$ext file to $target_dir"
  info "Resume target: $output_file"
  curl -fL --retry 2 --continue-at - -A "Mozilla/5.0" -o "$output_file" "$url"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "File download finished: $output_file"
    scan_media "$target_dir"
    record_history document "$url"
  else
    err "File download failed (exit code $rc)."
    info "If a partial file exists, retry the same URL to continue into that file."
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
