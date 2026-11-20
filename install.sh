#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
BIN_DIR="$HOME/bin"
BASHRC="$HOME/.bashrc"

if [ ! -f "$ROOT/termux-url-opener" ] || [ ! -d "$ROOT/lib" ] || [ ! -d "$ROOT/modules" ]; then
  printf '[ERR] Run this installer from the CyberForge project folder.\n' >&2
  exit 1
fi

mkdir -p "$BIN_DIR"
cp "$ROOT/termux-url-opener" "$BIN_DIR/termux-url-opener"
cp "$ROOT/help_script" "$BIN_DIR/cyber-help"
chmod +x "$BIN_DIR/termux-url-opener" "$BIN_DIR/cyber-help"

touch "$BASHRC"
grep -Fq 'export PATH="$HOME/bin:$PATH"' "$BASHRC" || printf '%s\n' 'export PATH="$HOME/bin:$PATH"' >> "$BASHRC"
grep -Fq 'alias DL=' "$BASHRC" || printf '%s\n' "alias DL='bash \$HOME/bin/termux-url-opener'" >> "$BASHRC"
grep -Fq 'alias dl=' "$BASHRC" || printf '%s\n' "alias dl='bash \$HOME/bin/termux-url-opener'" >> "$BASHRC"
grep -Fq 'alias cyberforge=' "$BASHRC" || printf '%s\n' "alias cyberforge='bash \$HOME/bin/termux-url-opener'" >> "$BASHRC"
grep -Fq 'alias cyber-help=' "$BASHRC" || printf '%s\n' "alias cyber-help='bash \$HOME/bin/cyber-help'" >> "$BASHRC"

printf '\n[OK] CyberForge launchers installed.\n'
printf 'Run: source ~/.bashrc\n'
printf 'Then use: DL or cyberforge\n'
printf 'Help: cyber-help\n'
printf 'Android Share integration: ~/bin/termux-url-opener\n'
