#!/data/data/com.termux/files/usr/bin/bash
movie_search() {
  local q encoded google justwatch imdb
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
  info "Choose a search destination. Availability depends on your country and subscriptions."
  info "This tool only helps locate legitimate streaming, rental, library, or official distribution sources."
  ask "Open which result? " choice
  case "$choice" in
    1) termux-open-url "$google" 2>/dev/null || printf "Open: %s\n" "$google" ;;
    2) termux-open-url "$justwatch" 2>/dev/null || printf "Open: %s\n" "$justwatch" ;;
    3) termux-open-url "$imdb" 2>/dev/null || printf "Open: %s\n" "$imdb" ;;
    *) return 0 ;;
  esac
}
