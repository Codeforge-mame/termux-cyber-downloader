#!/data/data/com.termux/files/usr/bin/bash
# CyberForge terminal theme with portable width detection.

G='\033[1;32m'; C='\033[1;36m'; Y='\033[1;33m'; R='\033[1;31m'; W='\033[1;37m'; D='\033[0;90m'; N='\033[0m'

# Return a sensible terminal width even when tput/stty are unavailable.
term_width() {
  local width=""
  if command -v tput >/dev/null 2>&1; then
    width="$(tput cols 2>/dev/null || true)"
  fi
  if ! [[ "$width" =~ ^[0-9]+$ ]] || (( width < 20 )); then
    width="${COLUMNS:-}"
  fi
  if ! [[ "$width" =~ ^[0-9]+$ ]] || (( width < 20 )); then
    width="$(stty size 2>/dev/null | awk '{print $2}')"
  fi
  if ! [[ "$width" =~ ^[0-9]+$ ]] || (( width < 20 )); then
    width=40
  fi
  (( width > 100 )) && width=100
  printf '%s' "$width"
}

banner() {
  local title="$1" width inner left right line
  width="$(term_width)"
  (( width > 64 )) && width=64
  (( width < 24 )) && width=24
  inner=$((width - 4))

  if (( ${#title} > inner )); then
    title="${title:0:inner}"
  fi
  left=$(((inner - ${#title}) / 2))
  right=$((inner - ${#title} - left))
  printf -v line '%*s' "$inner" ''
  line="${line// /=}"

  printf '\n%b+%s+%b\n' "$G" "$line" "$N"
  printf '%b|%*s%s%*s|%b\n' "$G" "$left" '' "$title" "$right" '' "$N"
  printf '%b+%s+%b\n' "$G" "$line" "$N"
}

info() { printf "%b[INFO]%b %s\n" "$C" "$N" "$*"; }
ok() { printf "%b[OK]%b %s\n" "$G" "$N" "$*"; }
warn() { printf "%b[WARN]%b %s\n" "$Y" "$N" "$*"; }
err() { printf "%b[ERR]%b %s\n" "$R" "$N" "$*" >&2; }
ask() {
  local prompt="$1" __var="$2" answer
  read -r -p "$(printf '%b' "${Y}$prompt${N}")" answer
  printf -v "$__var" '%s' "$answer"
}
