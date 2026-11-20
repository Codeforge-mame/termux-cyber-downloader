#!/data/data/com.termux/files/usr/bin/bash

tool_versions() {
  banner "INSTALLED TOOL VERSIONS"
  local cmd
  for cmd in yt-dlp ffmpeg tdl curl python gallery-dl; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf " %-12s %s\n" "$cmd" "$("$cmd" --version 2>/dev/null | head -n 1 || "$cmd" -version 2>/dev/null | head -n 1 || echo installed)"
    else
      printf " %-12s %s\n" "$cmd" "not installed"
    fi
  done
  if python -c 'import PIL' >/dev/null 2>&1; then
    printf " %-12s %s\n" "Pillow" "$(python -c 'import PIL; print(PIL.__version__)')"
  else
    printf " %-12s %s\n" "Pillow" "not installed"
  fi
}

update_python_tool() {
  local package="$1"
  python -m pip install --upgrade "$package"
}

update_all_tools() {
  info "Updating Termux packages, including FFmpeg and tdl..."
  pkg update && pkg upgrade -y || return $?
  info "Updating yt-dlp..."
  update_python_tool yt-dlp || return $?
  if python -m pip show gallery-dl >/dev/null 2>&1; then
    info "Updating gallery-dl..."
    update_python_tool gallery-dl || return $?
  fi
  if python -m pip show pillow >/dev/null 2>&1; then
    info "Updating Pillow..."
    update_python_tool pillow || return $?
  fi
  ok "Installed Termux and Python tools have been updated."
}

check_tool_updates() {
  banner "CHECK FOR TOOL UPDATES"
  info "Refreshing Termux package information..."
  pkg update || return $?
  printf "\n--- Termux packages with updates ---\n"
  apt list --upgradable 2>/dev/null || true
  printf "\n--- Python packages with updates ---\n"
  python -m pip list --outdated || true
}

tools_update_menu() {
  local choice confirm
  while true; do
    banner "CYBERFORGE TOOL UPDATE CENTER"
    printf " 1) Update all Termux packages (includes FFmpeg and tdl)\n"
    printf " 2) Update yt-dlp\n"
    printf " 3) Update optional Python media tools (gallery-dl / Pillow)\n"
    printf " 4) Update all installed CyberForge tools\n"
    printf " 5) Show installed tool versions\n"
    printf " 0) Back\n"
    ask "Choose: " choice
    case "$choice" in
      1)
        ask "Update all Termux packages now? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] && { pkg update && pkg upgrade -y; }
        ;;
      2) update_python_tool yt-dlp ;;
      3)
        if python -m pip show gallery-dl >/dev/null 2>&1; then update_python_tool gallery-dl; else info "gallery-dl is not installed."; fi
        if python -m pip show pillow >/dev/null 2>&1; then update_python_tool pillow; else info "Pillow is not installed."; fi
        ;;
      4)
        ask "Update Termux packages and installed Python tools now? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] && update_all_tools
        ;;
      5) tool_versions ;;
      6) check_tool_updates ;;
      0|"") return 0 ;;
      *) warn "Unknown update option." ;;
    esac
    printf "\n"
    ask "Return to update center? [Y/n]: " confirm
    [[ "$confirm" =~ ^[Nn]$ ]] && return 0
  done
}
