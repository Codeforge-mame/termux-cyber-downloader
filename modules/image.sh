#!/data/data/com.termux/files/usr/bin/bash

image_download() {
  local url="${1:-}" clean_url rc
  [ -n "$url" ] || ask_url "Image or post URL: " url || return 1
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
  [ -n "$url" ] || ask_url "Video URL for thumbnail: " url || return 1
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
  ask_choice "Choose: " choice "1 2 0" || return 1
  case "$choice" in
    1)
      [ -n "$url" ] || ask_url "Image or post URL: " url || return 1
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
  ask_choice "Choose operation: " choice "0 1 2 3 4 5 6 7 8 9 10 11" || return 1

  case "$choice" in
    0|"") return 0 ;;
    11)
      require_cmd python python || return 1
      ask "Folder containing images (default Pictures): " pdf_src
      pdf_src="${pdf_src:-$PIC_DIR}"
      ask "PDF output name (default combined_images.pdf): " pdf_name
      pdf_name="${pdf_name:-combined_images.pdf}"
      [[ "$pdf_name" == *.pdf ]] || pdf_name="$pdf_name.pdf"
      python - "$pdf_src" "$DOC_DIR/$pdf_name" <<'PY'
import glob, os, sys
try:
    from PIL import Image
except ImportError:
    print("Pillow is required: pip install pillow")
    raise SystemExit(1)
src, out = sys.argv[1], sys.argv[2]
files = sorted(f for pattern in ("*.jpg", "*.jpeg", "*.png", "*.webp") for f in glob.glob(os.path.join(src, pattern)))
if not files:
    print("No supported images found.")
    raise SystemExit(1)
images = []
for path in files[:100]:
    try:
        with Image.open(path) as im:
            images.append(im.convert("RGB").copy())
    except Exception:
        continue
if not images:
    print("No readable images found.")
    raise SystemExit(1)
images[0].save(out, save_all=True, append_images=images[1:])
print(f"Created {out} from {len(images)} image(s).")
PY
      rc=$?
      [ "$rc" -eq 0 ] && scan_media "$DOC_DIR"
      return "$rc"
      ;;
    1|2|3|4|5|6|7|8|9|10) ;;
    *) warn "Unknown image operation."; return 1 ;;
  esac

  if [ -z "$source" ]; then
    image_choose_source || return 1
    source="$IMAGE_SOURCE"
  fi
  [ -f "$source" ] || { err "Image file not found."; return 1; }
  require_cmd ffmpeg ffmpeg || return 1
  stem="${source%.*}"
  ext="${source##*.}"

  case "$choice" in
    1)
      out="${stem}_1x1.jpg"
      ffmpeg -y -v error -i "$source" -vf "crop='min(iw,ih)':'min(iw,ih)',scale=1080:1080" "$out"
      ;;
    2)
      out="${stem}_16x9.jpg"
      ffmpeg -y -v error -i "$source" -vf "scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080" "$out"
      ;;
    3)
      out="${stem}_9x16.jpg"
      ffmpeg -y -v error -i "$source" -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920" "$out"
      ;;
    4)
      out="${stem}_4x5.jpg"
      ffmpeg -y -v error -i "$source" -vf "scale=1080:1350:force_original_aspect_ratio=increase,crop=1080:1350" "$out"
      ;;
    5)
      ask_choice "Target frame: 1) Square 2) Wide 3) Vertical: " choice "1 2 3" || return 1
      w=1080; h=1080
      [[ "$choice" == "2" ]] && w=1920 && h=1080
      [[ "$choice" == "3" ]] && w=1080 && h=1920
      out="${stem}_blurfit.jpg"
      ffmpeg -y -v error -i "$source" -filter_complex "[0:v]scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h},boxblur=25:5[bg];[0:v]scale=${w}:${h}:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2" "$out"
      ;;
    6)
      ask_choice "Output format (jpg/png/webp): " fmt "jpg JPG png PNG webp WEBP" || return 1
      fmt="${fmt,,}"
      out="${stem}_optimized.$fmt"
      ffmpeg -y -v error -i "$source" -vf "scale='min(1440,iw)':-2" "$out"
      ;;
    7)
      out="${stem}_clean.${ext,,}"
      ffmpeg -y -v error -i "$source" -map_metadata -1 -c:v copy "$out"
      ;;
    8)
      ask_pattern "Dimensions (width x height, e.g. 800x600): " fmt "^[0-9]{2,5}x[0-9]{2,5}$" "Use dimensions like 800x600." || return 1
      w="${fmt%x*}"; h="${fmt#*x}"; out="${stem}_${fmt}.jpg"
      ffmpeg -y -v error -i "$source" -vf "scale=$w:$h:force_original_aspect_ratio=increase,crop=$w:$h" "$out"
      ;;
    9)
      out="$PIC_DIR/Expo_Assets"; mkdir -p "$out"
      ffmpeg -y -v error -i "$source" -vf "crop='min(iw,ih)':'min(iw,ih)',scale=1024:1024" "$out/icon.png" || return 1
      ffmpeg -y -v error -i "$source" -vf "crop='min(iw,ih)':'min(iw,ih)',scale=660:660,pad=1024:1024:(ow-iw)/2:(oh-ih)/2:color=0x00000000" "$out/adaptive-icon.png" || return 1
      ask "Splash background hex color (default #FFFFFF): " bg
      bg="${bg:-#FFFFFF}"
      ffmpeg -y -v error -f lavfi -i "color=c=$bg:s=1284x2778" -i "$source" -filter_complex "[1:v]crop='min(iw,ih)':'min(iw,ih)',scale=520:520[logo];[0:v][logo]overlay=(W-w)/2:(H-h)/2" -frames:v 1 "$out/splash-icon.png" || return 1
      ffmpeg -y -v error -i "$out/icon.png" -vf "scale=48:48" "$out/favicon.png"
      ffmpeg -y -v error -i "$out/icon.png" -vf "scale=96:96" "$out/notification-icon.png"
      ok "Expo assets saved to $out"; scan_media "$out"; return 0
      ;;
    10)
      out="$PIC_DIR/Web_Assets"; mkdir -p "$out"
      ffmpeg -y -v error -i "$source" -vf "scale=1200:630:force_original_aspect_ratio=increase,crop=1200:630" "$out/og-banner-1200x630.png" || return 1
      ffmpeg -y -v error -i "$source" -vf "crop='min(iw,ih)':'min(iw,ih)',scale=512:512" "$out/icon-512.png" || return 1
      ffmpeg -y -v error -i "$source" -vf "crop='min(iw,ih)':'min(iw,ih)',scale=192:192" "$out/icon-192.png"
      ffmpeg -y -v error -i "$source" -vf "crop='min(iw,ih)':'min(iw,ih)',scale=180:180" "$out/apple-touch-icon.png"
      ok "Web assets saved to $out"; scan_media "$out"; return 0
      ;;
  esac
  rc=$?
  if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
    ok "Saved: $out"
    scan_media "$(dirname "$out")"
  fi
  return "$rc"
}

image_menu() {
  local url="${1:-}" choice
  while true; do
    banner "IMAGE & MEDIA TOOLS"
    printf " 1) Download image / social gallery\n 2) Download video thumbnail\n 3) Process an image / create asset pack\n 0) Back\n"
    ask_choice "Choose: " choice "1 2 3 0" || return 1
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
