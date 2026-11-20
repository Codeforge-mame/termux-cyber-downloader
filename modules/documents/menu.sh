#!/data/data/com.termux/files/usr/bin/bash
document_manager_menu() {
  local choice
  while true; do
    banner "DOCUMENT MANAGER"
    printf '%s\n' \
      " 1) Find local files" \
      " 2) Download a document / file" \
      " 0) Back to main menu"
    ask "documents> " choice
    case "$choice" in
      1) document_local_search ;;
      2) document_download "" ;;
      0|q|Q) break ;;
      *) warn "Unknown selection." ;;
    esac
    printf '\n'
    local again
    ask "Return to Document Manager? [Y/n]: " again
    [[ "$again" =~ ^[Nn]$ ]] && break
  done
}
