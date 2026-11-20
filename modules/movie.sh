#!/data/data/com.termux/files/usr/bin/bash
movie_search() {
  local q encoded google justwatch imdb choice video_url threads_choice threads rc
  ask "Movie or series title: " q
  [ -n "$q" ] || return 0
  encoded="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$q" 2>/dev/null)"
  [ -n "$encoded" ] || { err "Could not encode the title. Check that Python 3 is installed."; return 1; }

  google="https://www.google.com/search?q=$encoded+official+watch"
  justwatch="https://www.justwatch.com/us/search?q=$encoded"
  imdb="https://www.imdb.com/find/?q=$encoded"

  banner "LEGAL MOVIE & SERIES SEARCH"
  printf " 1) Google: official streaming / rental / purchase\n 2) JustWatch: streaming availability\n 3) IMDb: title details and official links\n 0) Back\n"
  printf "\nGoogle: %s\nJustWatch: %s\nIMDb: %s\n\n" "$google" "$justwatch" "$imdb"
  info "Choose a legitimate streaming, rental, library, or official distribution source."
  ask "Open which result? " choice
  case "$choice" in
    1) termux-open-url "$google" 2>/dev/null || printf "Open: %s\n" "$google" ;;
    2) termux-open-url "$justwatch" 2>/dev/null || printf "Open: %s\n" "$justwatch" ;;
    3) termux-open-url "$imdb" 2>/dev/null || printf "Open: %s\n" "$imdb" ;;
    *) return 0 ;;
  esac

  printf "\n"
  info "After choosing a source, paste its video/page URL only if that source permits downloading."
  ask "Authorized video/page URL (or Enter to stop): " video_url
  [ -n "$video_url" ] || { info "Search finished. No download started."; return 0; }
  valid_url "$video_url" || { err "Please enter a valid http(s) URL."; return 1; }

  resolution_menu || return 0

  banner "MOVIE DOWNLOAD THREADS"
  printf " 1) 1 thread (conservative)\n 2) 2 threads\n 3) 4 threads\n 4) 8 threads (faster where supported)\n 0) Cancel\n"
  ask "Choose thread count [default 2]: " threads_choice
  case "$threads_choice" in
    0) info "Movie download cancelled."; return 0 ;;
    1) threads=1 ;;
    2|"") threads=2 ;;
    3) threads=4 ;;
    4) threads=8 ;;
    *) warn "Invalid thread choice."; return 1 ;;
  esac

  info "Resolving and downloading the selected source..."
  run_ytdlp -4 -N "$threads" --continue --download-archive "$ARCHIVE_FILE" -f "$FORMAT" --merge-output-format mp4 -P "$VIDEO_DIR" -o "$OUT_TMPL" "$video_url"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    record_history movie "$video_url"
    scan_media "$VIDEO_DIR"
    ok "Movie/series download completed."
  fi
  return "$rc"
}
