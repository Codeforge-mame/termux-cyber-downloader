#!/data/data/com.termux/files/usr/bin/bash
# Matrix green/cyan theme
G='\033[1;32m'; C='\033[1;36m'; Y='\033[1;33m'; R='\033[1;31m'; W='\033[1;37m'; D='\033[0;90m'; N='\033[0m'
banner() { printf "\n%b╔══════════════════════════════════════════╗%b\n%b║  %s  %b\n%b╚══════════════════════════════════════════╝%b\n" "$G" "$N" "$C" "$1" "$G" "$N"; }
info() { printf "%b[INFO]%b %s\n" "$C" "$N" "$*"; }
ok() { printf "%b[OK]%b %s\n" "$G" "$N" "$*"; }
warn() { printf "%b[WARN]%b %s\n" "$Y" "$N" "$*"; }
err() { printf "%b[ERR]%b %s\n" "$R" "$N" "$*" >&2; }
ask() { local prompt="$1" __var="$2" answer; read -r -p "$(printf '%b' "${Y}$prompt${N}")" answer; printf -v "$__var" '%s' "$answer"; }
