#!/data/data/com.termux/files/usr/bin/bash

image_download() {
  local url="${1:-}" clean_url rc
  [ -n "$url" ] || ask "Image or post URL: " url
  valid_url "$url" || { err "Please enter a valid http(s) URL."; return 1; }
  mkdir -p "$PIC_DIR"
  clean_url="${url%%\?*}"

  if [[ "${clean_url,,}" =~ \.(jpg|jpeg|png|webp|gif|bmp|avif)$ ]]; then
    require_cmd curl curl || return 1
    curl -fL --retry 2 -A "Mozilla/5.0" -J -O --output-dir "$PIC_DIR" "$url"
    rc=$?
  elif command -v gallery-dl >/dev/null 2>&1; then
    gallery-dl -d "$PIC_DIR" --directory "" "$url"
    rc=$?
  else
    err "This looks like a social/gallery post. Install gallery-dl to download images from it."
    info "Install with: pip install -U gallery-dl"
    return 1
  fi

  if [ "$rc" -eq 0 ]; then
    scan_media "$PIC_DIR"
    ok "Image download finished. Saved under $PIC_DIR"
  else
    err "Image download failed (exit code $rc)."
  fi
  return "$rc"
}

thumbnail_download() {
  local url="${1:-}"
  [ -n "$url" ] || ask "Video URL for thumbnail: " url
  valid_url "$url" || { err "Please enter a valid http(s) URL."; return 1; }
  require_cmd yt-dlp yt-dlp || return 1
  mkdir -p "$PIC_DIR"
  yt-dlp --write-thumbnail --convert-thumbnails jpg --skip-download -P "$PIC_DIR" -o "%(title)s.%(ext)s" "$url"
  local rc=$?
  [ "$rc" -eq 0 ] && { scan_media "$PIC_DIR"; ok "Thumbnail saved under $PIC_DIR"; }
  return "$rc"
}

image_pick_local() {
  local query path
  ask "Search image name (Enter = latest 15): " query
  local -a images=()
  if [ -n "$query" ]; then
    mapfile -t images < <(find -L "$HOME/storage/shared" -path "*/Android/data" -prune -o -path "*/Android/obb" -prune -o -type f \( -iname "*$query*.jpg" -o -iname "*$query*.jpeg" -o -iname "*$query*.png" -o -iname "*$query*.webp" \) -print 2>/dev/null | head -n 15)
  else
    mapfile -t images < <(find -L "$HOME/storage/shared" -path "*/Android/data" -prune -o -path "*/Android/obb" -prune -o -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print 2>/dev/null | head -n 15)
  fi
  [ "${#images[@]}" -gt 0 ] || { warn "No matching images found."; return 1; }
  local i selection
  for i in "${!images[@]}"; do printf " %2d) %s\n" "$((i+1))" "${images[$i]#"$HOME/storage/shared/"}"; done
  ask "Select image number (0 = cancel): " selection
  [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#images[@]}" ] || return 1
  IMAGE_SOURCE="${images[$((selection-1))]}"
}

image_choose_source() {
  local url="${1:-}" choice temp rc found
  banner "SELECT IMAGE SOURCE"
  printf " 1) Download from URL / social post\n 2) Pick an image from phone storage\n 0) Cancel\n"
  ask "Choose: " choice
  case "$choice" in
    1)
      [ -n "$url" ] || ask "Image or post URL: " url
      valid_url "$url" || return 1
      temp="$(mktemp -d)" || return 1
      local clean="${url%%\?*}"
      if [[ "${clean,,}" =~ \.(jpg|jpeg|png|webp|gif|bmp|avif)$ ]]; then
        curl -fLsS -A "Mozilla/5.0" -J -O --output-dir "$temp" "$url"
        rc=$?
      elif command -v gallery-dl >/dev/null 2>&1; then
        gallery-dl -d "$temp" --directory "" "$url"
        rc=$?
      else
        err "Install gallery-dl for social/gallery post URLs."
        rm -rf "$temp"
        return 1
      fi
      if [ "$rc" -eq 0 ]; then
        found="$(find "$temp" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print -quit)"
      fi
      if [ -n "$found" ]; then
        local target="$PIC_DIR/$(basename "$found")"
        mkdir -p "$PIC_DIR"
        cp -n "$found" "$target" 2>/dev/null || { target="$PIC_DIR/$(date +%s)_$(basename "$found")"; cp "$found" "$target"; }
        rm -rf "$temp"
        IMAGE_SOURCE="$target"
      else
        rm -rf "$temp"
        err "No supported image was found at that URL."
        return 1
      fi
      ;;
    2) image_pick_local ;;
    *) return 1 ;;
  esac
}

image_process_menu() {
  local source="${1:-}" choice stem ext out w h fmt bg pdf_src pdf_name rc
  banner "IMAGE & ASSET TOOLKIT"
  printf " 1) Square crop (1080x1080)\n 2) Widescreen (1920x1080)\n 3) Vertical (1080x1920)\n 4) Portrait (1080x1350)\n 5) Blurred background fit\n 6) Convert / compress (JPG, PNG, WebP)\n 7) Strip EXIF / GPS metadata\n 8) Custom dimensions\n 9) Expo icon and splash asset pack\n10) Web / PWA icon and OG banner pack\n11) Combine images into PDF\n 0) Back\n"
  ask "Choose operation: " choice
  case "$choice" in
    0|"") return 0 ;;
    *) warn "Unknown image operation."; return 1 ;;
  esac
  rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$out" ]; then ok "Saved: $out"; scan_media "$(dirname "$out")"; fi
  return "$rc"
}

image_menu() {
  local url="${1:-}" choice
  while true; do
    banner "IMAGE & MEDIA TOOLS"
    printf " 1) Download image / social gallery\n 2) Download video thumbnail\n 3) Process an image / create asset pack\n 0) Back\n"
    ask "Choose: " choice
    case "$choice" in
      1) image_download "$url"; url="" ;;
      2) thumbnail_download "$url"; url="" ;;
      3) image_process_menu ;;
      0|"") return 0 ;;
      *) warn "Unknown image option." ;;
    esac
    printf "\n"
  done
}
