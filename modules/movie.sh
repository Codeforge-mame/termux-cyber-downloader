#!/data/data/com.termux/files/usr/bin/bash
movie_search() {
  local q
  ask "Movie or series title: " q
  [ -n "$q" ] || return 0
  info "Search for the title and check legitimate streaming, rental, library, or official distribution sources."
  local encoded
  encoded="$(python -c 'import sys,urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))' "$q" 2>/dev/null)"
  if [ -z "$encoded" ]; then encoded="$q"; fi
  printf "Open search results: https://www.google.com/search?q=%s+official+watch\n" "$encoded"
  printf "Also check your local streaming services and the distributor's official site. This tool does not fetch pirated copies.\n"
}
