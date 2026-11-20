#!/data/data/com.termux/files/usr/bin/bash
# Read-only local filename search for CyberForge Document Manager.

DOC_SEARCH_LABELS=()
DOC_SEARCH_PATHS=()

document_search_add_root() {
  local label="$1" path="$2" resolved existing probe writable=0
  [ -d "$path" ] || return 0
  resolved="$(readlink -f "$path" 2>/dev/null)"
  [ -n "$resolved" ] || resolved="$path"
  for existing in "${DOC_SEARCH_PATHS[@]}"; do
    [ "$existing" = "$resolved" ] && return 0
  done
  # Probe actual access: Android scoped storage can deny access despite -r/-x.
  ls -A -- "$resolved" >/dev/null 2>&1 || return 0
  probe="$(mktemp "$resolved/.cyberforge-access.XXXXXX" 2>/dev/null)" && {
    writable=1
    rm -f -- "$probe" 2>/dev/null || writable=0
  }
  DOC_SEARCH_PATHS+=("$resolved")
  DOC_SEARCH_LABELS+=("$label")
  DOC_SEARCH_WRITABLE+=("$writable")
}
document_search_discover_roots() {
  DOC_SEARCH_LABELS=()
  DOC_SEARCH_PATHS=()
  DOC_SEARCH_WRITABLE=()
  document_search_add_root "Internal shared storage" "$HOME/storage/shared"
  document_search_add_root "Internal shared storage" "/storage/emulated/0"
  document_search_add_root "Internal shared storage" "/sdcard"

  # Termux storage setup may create external-N links for removable media.
  local path name index
  for index in {1..8}; do
    path="$HOME/storage/external-$index"
    [ -e "$path" ] || continue
    name="${path##*/}"
    document_search_add_root "Removable storage: $name" "$path"
  done

  # Android SD cards commonly mount as /storage/XXXX-XXXX; USB/OTG paths vary.
  for path in /storage/* /mnt/media_rw/* /mnt/user/*; do
    [ -d "$path" ] || continue
    name="${path##*/}"
    case "$name" in emulated|self|media_rw|user|pass_through) continue ;; esac
    document_search_add_root "SD / external storage: $name" "$path"
  done
}
document_file_category() {
  local ext="${1,,}"
  case "$ext" in
    pdf|doc|docx|odt|rtf|txt|md|html|htm) printf 'Document' ;;
    csv|xls|xlsx|ods) printf 'Spreadsheet' ;;
    ppt|pptx|odp) printf 'Presentation' ;;
    jpg|jpeg|png|webp|bmp|gif|tif|tiff) printf 'Image' ;;
    *) printf 'Other / unsupported for planned conversion' ;;
  esac
}

document_file_is_known() {
  local ext="${1,,}"
  case "$ext" in
    pdf|doc|docx|odt|rtf|txt|md|html|htm|csv|xls|xlsx|ods|ppt|pptx|odp|jpg|jpeg|png|webp|bmp|gif|tif|tiff)
      return 0 ;;
    *) return 1 ;;
  esac
}

document_file_size() {
  local path="$1" bytes
  bytes="$(stat -c '%s' -- "$path" 2>/dev/null)"
  if [[ "$bytes" =~ ^[0-9]+$ ]]; then
    if (( bytes >= 1073741824 )); then
      awk -v n="$bytes" 'BEGIN { printf "%.2f GB", n/1073741824 }'
    elif (( bytes >= 1048576 )); then
      awk -v n="$bytes" 'BEGIN { printf "%.2f MB", n/1048576 }'
    elif (( bytes >= 1024 )); then
      awk -v n="$bytes" 'BEGIN { printf "%.1f KB", n/1024 }'
    else
      printf '%s bytes' "$bytes"
    fi
  else
    printf 'Unknown'
  fi
}

document_selected_file_info() {
  local path="$1" name ext mime category size
  [ -f "$path" ] && [ -r "$path" ] || {
    err "The selected file no longer exists or is not readable."
    return 1
  }

  name="${path##*/}"
  ext="${name##*.}"
  [ "$ext" = "$name" ] && ext="" || ext="${ext,,}"
  category="$(document_file_category "$ext")"
  size="$(document_file_size "$path")"

  banner "FILE VALIDATION"
  printf 'Name:       %s\n' "$name"
  printf 'Location:   %s\n' "$path"
  printf 'Size:       %s\n' "$size"
  printf 'Extension:  %s\n' "${ext:-none}"
  printf 'Category:   %s\n' "$category"
  printf 'Readable:   YES\n'
  if command -v file >/dev/null 2>&1; then
    mime="$(file -b --mime-type -- "$path" 2>/dev/null)"
    [ -n "$mime" ] && printf 'MIME type:  %s\n' "$mime"
  fi

  if document_file_is_known "$ext"; then
    ok "Recognized file type. It can be considered by the conversion phase."
    info "Conversion is not enabled in Phase 1; the original file has not been changed."
  else
    warn "This file type is not in the planned conversion list yet."
    info "The file remains untouched."
  fi

  printf '\n'
  printf '1) Open with Android (if termux-open is available)\n'
  printf '0) Back\n'
  local action
  ask_choice "Select action: " action "1 0" || return 1
  case "$action" in
    1)
      if command -v termux-open >/dev/null 2>&1; then
        termux-open "$path"
      else
        warn "termux-open is unavailable. Install the Termux:API app and package if you need Android open-with support."
      fi
      ;;
    0|"") ;;
    *) warn "Unknown selection." ;;
  esac
}


# Shared numbered-result manager. Search itself remains read-only; changes happen
# only after the user explicitly selects files and confirms an operation.
document_manage_matches() {
  local title="$1" choice token start end n idx src dest base ext stem candidate suffix action
  local selection copied moved deleted failed skipped=0 tmpcopy source_real target_real attempt valid allowed
  local -a visible=() selected=() tokens=()
  local -A seen=()
  local total="${#DOC_RESULT_FILES[@]}"

  (( total > 0 )) || { warn "No matching files were found."; return 0; }
  banner "$title"
  printf 'Found %s matching file(s).\n' "$total"
  for idx in "${!DOC_RESULT_FILES[@]}"; do
    (( idx >= 100 )) && break
    visible+=("${DOC_RESULT_FILES[$idx]}")
    printf '\n%s) %s\n   %s\n' "$((idx + 1))" "${DOC_RESULT_FILES[$idx]##*/}" "${DOC_RESULT_FILES[$idx]}"
  done
  (( total > 100 )) && warn "Showing the first 100 results. Narrow the search before managing files."
  printf '\n'
  valid=0
  for ((attempt=1; attempt<=3; attempt++)); do
    selected=(); tokens=(); seen=()
    ask "Select files (e.g. 1 35 74 or 1-5; 0 to return): " selection
    [[ "$selection" == "0" || -z "$selection" ]] && return 0
    selection="${selection//,/ }"
    read -r -a tokens <<< "$selection"
    valid=1
    for token in "${tokens[@]}"; do
      if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        start="${BASH_REMATCH[1]}"; end="${BASH_REMATCH[2]}"
        if (( start < 1 || end < start || end > ${#visible[@]} )); then
          err "Invalid range: $token. Choose between 1 and ${#visible[@]} (attempt $attempt/3)."
          valid=0; break
        fi
        for ((n=start; n<=end; n++)); do
          idx=$((n - 1))
          if [[ -z "${seen[$idx]+x}" ]]; then selected+=("${visible[$idx]}"); seen[$idx]=1; fi
        done
      elif [[ "$token" =~ ^[0-9]+$ ]] && (( token >= 1 && token <= ${#visible[@]} )); then
        idx=$((token - 1))
        if [[ -z "${seen[$idx]+x}" ]]; then selected+=("${visible[$idx]}"); seen[$idx]=1; fi
      else
        err "Invalid file selection: $token. Use indexes such as 1 3 5 or ranges like 1-5 (attempt $attempt/3)."
        valid=0; break
      fi
    done
    (( valid == 1 )) && break
  done
  if (( valid == 0 )); then
    warn "Maximum attempts reached. Returning to the previous menu."
    return 1
  fi

  (( ${#selected[@]} > 0 )) || return 0
  banner "SELECTED FILES"
  printf 'Selected %s file(s):\n' "${#selected[@]}"
  for src in "${selected[@]}"; do printf ' - %s\n' "${src##*/}"; done
  printf '\n'
  printf '%s\n' " 1) Copy" " 2) Move" " 3) Delete" " 0) Cancel"
  ask_choice "Choose operation: " action "1 2 3 0" || return 1

  case "$action" in
    0|"") return 0 ;;
    3)
      printf '\n'
      warn "Deletion is permanent. These files will be removed:"
      for src in "${selected[@]}"; do printf ' - %s\n' "$src"; done
      ask_choice "Type DELETE to confirm: " choice "DELETE" || { info "Deletion cancelled."; return 0; }
      deleted=0; failed=0
      for src in "${selected[@]}"; do
        if [ -f "$src" ] && rm -- "$src" 2>/dev/null; then
          ((deleted += 1)); ok "Deleted: ${src##*/}"
        else
          ((failed += 1)); err "Could not delete: $src"
        fi
      done
      printf '\nDelete summary: %s deleted, %s failed.\n' "$deleted" "$failed"
      ;;
    1|2)
      document_search_discover_roots
      local -a writable_paths=() writable_labels=()
      for idx in "${!DOC_SEARCH_PATHS[@]}"; do
        if [[ "${DOC_SEARCH_WRITABLE[$idx]}" == "1" ]]; then
          writable_paths+=("${DOC_SEARCH_PATHS[$idx]}")
          writable_labels+=("${DOC_SEARCH_LABELS[$idx]}")
        fi
      done
      if (( ${#writable_paths[@]} == 0 )); then
        err "No writable storage destination was detected."
        info "Check Android storage permission and run termux-setup-storage again."
        return 1
      fi
      printf '\\nWRITABLE DESTINATION LOCATIONS\\n'
      for idx in "${!writable_paths[@]}"; do
        printf ' %s) %s\\n    %s\\n' "$((idx + 1))" "${writable_labels[$idx]}" "${writable_paths[$idx]}"
      done
      printf ' 0) Cancel\\n'
      allowed="0"
      for idx in "${!writable_paths[@]}"; do allowed+=" $((idx + 1))"; done
      ask_choice "Choose destination location: " choice "$allowed" || return 1
      [[ "$choice" == "0" ]] && return 0
      dest="${writable_paths[$((choice - 1))]}"
      ask "Destination folder (blank = selected location): " base
      if [[ -n "$base" ]]; then
        if [[ "$base" = /* ]]; then dest="$base"; else dest="$dest/$base"; fi
      fi
      if [ -e "$dest" ] && [ ! -d "$dest" ]; then
        err "Destination exists but is not a directory."; return 1
      fi
      if [ ! -d "$dest" ]; then
        ask "Directory does not exist. Create it? [y/N]: " choice
        [[ "$choice" =~ ^[Yy]$ ]] || { info "Operation cancelled."; return 0; }
        mkdir -p -- "$dest" 2>/dev/null || { err "Could not create destination directory."; return 1; }
      fi
      [ -w "$dest" ] && [ -x "$dest" ] || { err "Destination is not writable by Termux."; return 1; }

      copied=0; moved=0; failed=0
      for src in "${selected[@]}"; do
        [ -f "$src" ] && [ -r "$src" ] || { ((failed += 1)); err "Source unavailable: $src"; continue; }
        base="${src##*/}"
        candidate="$dest/$base"
        source_real="$(readlink -f "$src" 2>/dev/null)"
        target_real="$(readlink -f "$candidate" 2>/dev/null)"
        if [[ -n "$source_real" && "$source_real" == "$target_real" ]]; then
          ((skipped += 1)); warn "Source and destination are the same file; skipped: $base"; continue
        fi
        if [ -d "$candidate" ]; then
          ((skipped += 1)); warn "A directory with this filename already exists; skipped: $base"; continue
        fi
        if [ -e "$candidate" ]; then
          printf '\nDestination already contains: %s\n' "$base"
          printf '%s\n' " s) Skip" " r) Keep both (automatic new filename)" " o) Replace existing file"
          ask_choice "Choose for this file [s/r/o]: " choice "s S r R o O" || { ((skipped += 1)); continue; }
          case "$choice" in
            r|R)
              stem="$base"; ext=""
              if [[ "$base" == *.* && "$base" != .* ]]; then ext=".${base##*.}"; stem="${base%.*}"; fi
              suffix=1
              while [ -e "$dest/$stem (copy $suffix)$ext" ]; do ((suffix += 1)); done
              candidate="$dest/$stem (copy $suffix)$ext"
              ;;
            o|O)
              ask_choice "Type REPLACE to overwrite $base: " choice "REPLACE" || { ((skipped += 1)); info "Skipped: $base"; continue; }
              ;;
            *) ((skipped += 1)); info "Skipped: $base"; continue ;;
          esac
        fi
        # Stage beside the destination, verify bytes, then atomically publish.
        # This protects an existing destination if a copy is interrupted or fails.
        tmpcopy="$(mktemp "$dest/.cyberforge-copy.XXXXXX" 2>/dev/null)" || {
          ((failed += 1)); err "Could not create a temporary destination file."; continue;
        }
        if cp -p -- "$src" "$tmpcopy" 2>/dev/null && cmp -s -- "$src" "$tmpcopy" &&
           mv -f -- "$tmpcopy" "$candidate" 2>/dev/null; then
          ((copied += 1))
          if [[ "$action" == "2" ]]; then
            if rm -- "$src" 2>/dev/null; then
              ((moved += 1)); ok "Moved: ${src##*/}"
            else
              ((failed += 1)); err "Copied and verified, but could not remove original: $src"
            fi
          else
            ok "Copied: ${src##*/}"
          fi
        else
          rm -f -- "$tmpcopy" 2>/dev/null
          ((failed += 1)); err "Copy/verification failed; source retained: $src"
        fi
      done
      if [[ "$action" == "2" ]]; then
        printf '\nMove summary: %s moved, %s skipped, %s failed.\n' "$moved" "$skipped" "$failed"
        info "A source is removed only after its destination copy passes byte-for-byte verification."
      else
        printf '\nCopy summary: %s copied, %s skipped, %s failed.\n' "$copied" "$skipped" "$failed"
      fi
      ;;
    *) warn "Unknown operation." ;;
  esac
}

document_local_search() {
  local keyword choice index selected root tmp count=0 shown=0
  local -a roots=() labels=() matches=()
  document_search_discover_roots

  if (( ${#DOC_SEARCH_PATHS[@]} == 0 )); then
    err "No accessible shared or removable storage was detected."
    info "Run termux-setup-storage and grant Android storage permission, then try again."
    return 1
  fi

  banner "FIND LOCAL FILES"
  ask_nonempty "Filename or keyword: " keyword || return 1
  keyword="$(printf '%s' "$keyword" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  printf '\nSEARCH LOCATIONS\n'
  for index in "${!DOC_SEARCH_PATHS[@]}"; do
    printf ' %s) %s [%s]\n' "$((index + 1))" "${DOC_SEARCH_LABELS[$index]}" "$([ "${DOC_SEARCH_WRITABLE[$index]}" = "1" ] && printf "read/write" || printf "read only")"
  done
  printf ' a) All detected accessible locations\n'
  printf ' 0) Cancel\n'
  local allowed="0 a A"
  for index in "${!DOC_SEARCH_PATHS[@]}"; do allowed+=" $((index + 1))"; done
  ask_choice "Choose location: " choice "$allowed" || return 1

  case "$choice" in
    0|"") return 0 ;;
    a|A)
      roots=("${DOC_SEARCH_PATHS[@]}")
      labels=("${DOC_SEARCH_LABELS[@]}")
      ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#DOC_SEARCH_PATHS[@]} )); then
        roots=("${DOC_SEARCH_PATHS[$((choice - 1))]}")
        labels=("${DOC_SEARCH_LABELS[$((choice - 1))]}")
      else
        warn "Invalid storage selection."
        return 1
      fi
      ;;
  esac

  tmp="$(mktemp 2>/dev/null)" || { err "Could not create a temporary search file."; return 1; }
  info "Searching filenames for: $keyword"
  for index in "${!roots[@]}"; do
    info "Scanning: ${labels[$index]}"
    find "${roots[$index]}" -type f -iname "*$keyword*" -print0 2>/dev/null >> "$tmp"
  done

  while IFS= read -r -d '' selected; do
    matches+=("$selected")
  done < "$tmp"
  rm -f "$tmp"

  count="${#matches[@]}"
  if (( count == 0 )); then
    warn "No matching filenames were found in the selected accessible locations."
    info "Storage Android does not expose to Termux cannot be searched by this scanner."
    return 0
  fi
  DOC_RESULT_FILES=("${matches[@]}")
  document_manage_matches "FILENAME SEARCH RESULTS"
}

document_search_choose_roots() {
  local choice index allowed="0 a A"
  DOC_SELECTED_ROOTS=()
  document_search_discover_roots
  if (( ${#DOC_SEARCH_PATHS[@]} == 0 )); then
    err "No accessible shared or removable storage was detected."
    info "Run termux-setup-storage and grant Android storage permission, then try again."
    return 1
  fi
  printf '\nSEARCH LOCATIONS\n'
  for index in "${!DOC_SEARCH_PATHS[@]}"; do
    printf ' %s) %s [%s]\n' "$((index + 1))" "${DOC_SEARCH_LABELS[$index]}" "$([ "${DOC_SEARCH_WRITABLE[$index]}" = "1" ] && printf "read/write" || printf "read only")"
    allowed+=" $((index + 1))"
  done
  printf ' a) All detected accessible locations\n'
  printf ' 0) Cancel\n'
  ask_choice "Choose location: " choice "$allowed" || return 1
  case "$choice" in
    0) return 1 ;;
    a|A) DOC_SELECTED_ROOTS=("${DOC_SEARCH_PATHS[@]}") ;;
    *) DOC_SELECTED_ROOTS=("${DOC_SEARCH_PATHS[$((choice - 1))]}") ;;
  esac
}
document_search_show_matches() {
  local tmp="$1" title="$2" selected
  DOC_RESULT_FILES=()
  while IFS= read -r -d '' selected; do DOC_RESULT_FILES+=("$selected"); done < "$tmp"
  rm -f "$tmp"
  document_manage_matches "$title"
}

document_local_type_search() {
  local choice index ext tmp
  local -a extensions=()
  banner "SEARCH BY FILE TYPE"
  printf '%s\n' \
    " 1) PDF documents" \
    " 2) Word / text documents" \
    " 3) Spreadsheets" \
    " 4) Presentations" \
    " 5) Images" \
    " 6) Archives" \
    " 7) Audio files" \
    " 8) Video files" \
    " 9) APK / Android packages" \
    "10) Enter extension manually" \
    " 0) Back"
  ask_choice "Choose file type: " choice "1 2 3 4 5 6 7 8 9 10 0" || return 1
  case "$choice" in
    1) extensions=(pdf) ;;
    2) extensions=(doc docx odt rtf txt md) ;;
    3) extensions=(csv xls xlsx ods) ;;
    4) extensions=(ppt pptx odp) ;;
    5) extensions=(jpg jpeg png webp bmp gif tif tiff heic heif) ;;
    6) extensions=(zip rar 7z tar gz bz2 xz) ;;
    7) extensions=(mp3 m4a aac wav ogg flac opus) ;;
    8) extensions=(mp4 mkv mov avi webm m4v 3gp) ;;
    9) extensions=(apk xapk apks) ;;
    10)
      ask_pattern "File extension (without dot): " ext '^[A-Za-z0-9]+$' "Enter an extension using letters and numbers only." || return 1
      ext="${ext#.}"
      ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
      extensions=("$ext")
      ;;
    0) return 0 ;;
  esac

  document_search_choose_roots || return 0
  tmp="$(mktemp 2>/dev/null)" || { err "Could not create a temporary search file."; return 1; }
  info "Searching selected storage by extension..."
  for index in "${!DOC_SELECTED_ROOTS[@]}"; do
    for ext in "${extensions[@]}"; do
      find "${DOC_SELECTED_ROOTS[$index]}" -type f -iname "*.$ext" -print0 2>/dev/null >> "$tmp"
    done
  done
  document_search_show_matches "$tmp" "FILE TYPE RESULTS"
}


# Phase 3: convert supported documents without OCR. The source is never replaced.
document_conversion_menu() {
  local query choice idx src ext target from output stem suffix tmp rc attempt valid=0
  local -a roots=() candidates=()
  banner "DOCUMENT CONVERSION"
  if ! command -v pandoc >/dev/null 2>&1; then
    warn "Pandoc is needed for DOCX, ODT, EPUB, HTML, Markdown, RTF and TXT conversions."
    info "Install it with: pkg install pandoc"
    info "For selectable-text PDF conversion also install: pkg install poppler"
    return 1
  fi
  ask_nonempty "Search filename to convert: " query || return 1
  document_search_choose_roots || return 0
  roots=("${DOC_SELECTED_ROOTS[@]}")
  for idx in "${!roots[@]}"; do
    while IFS= read -r -d '' src; do candidates+=("$src"); done < <(
      find "${roots[$idx]}" -type f \( -iname '*.docx' -o -iname '*.odt' -o -iname '*.epub' -o -iname '*.html' -o -iname '*.htm' -o -iname '*.md' -o -iname '*.txt' -o -iname '*.rtf' -o -iname '*.pdf' \) -iname "*$query*" -print0 2>/dev/null
    )
  done
  if (( ${#candidates[@]} == 0 )); then
    warn "No supported documents matched that filename."
    return 0
  fi
  banner "SELECT DOCUMENT"
  for idx in "${!candidates[@]}"; do
    (( idx >= 100 )) && break
    printf '%s) %s\n   %s\n' "$((idx + 1))" "${candidates[$idx]##*/}" "${candidates[$idx]}"
  done
  (( ${#candidates[@]} > 100 )) && warn "Only the first 100 results are shown."
  for ((attempt=1; attempt<=3; attempt++)); do
    ask "Select document number (0 = cancel): " choice
    [[ "$choice" == "0" ]] && return 0
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= 100 && choice <= ${#candidates[@]} )); then
      valid=1; break
    fi
    err "Select a listed number or 0 to cancel (attempt $attempt/3)."
  done
  (( valid == 1 )) || { warn "Maximum attempts reached."; return 1; }
  src="${candidates[$((choice - 1))]}"
  [ -f "$src" ] && [ -r "$src" ] || { err "Selected file is not readable."; return 1; }
  ext="${src##*.}"; ext="${ext,,}"
  if [[ "$ext" == "pdf" ]]; then
    if ! command -v pdftotext >/dev/null 2>&1; then
      warn "PDF text extraction requires Poppler: pkg install poppler"
      info "Scanned PDFs are not supported because OCR is intentionally excluded."
      return 1
    fi
    printf '%s\n' " 1) TXT" " 2) DOCX" " 3) ODT" " 4) HTML" " 5) Markdown" " 0) Cancel"
    ask_choice "Convert PDF to: " choice "1 2 3 4 5 0" || return 1
    case "$choice" in
      1) target="txt" ;;
      2) target="docx" ;;
      3) target="odt" ;;
      4) target="html" ;;
      5) target="markdown" ;;
      *) return 0 ;;
    esac
  else
    printf '%s\n' " 1) DOCX" " 2) ODT" " 3) EPUB" " 4) HTML" " 5) Markdown" " 6) RTF" " 0) Cancel"
    ask_choice "Convert document to: " choice "1 2 3 4 5 6 0" || return 1
    case "$choice" in
      1) target="docx" ;;
      2) target="odt" ;;
      3) target="epub" ;;
      4) target="html" ;;
      5) target="markdown" ;;
      6) target="rtf" ;;
      *) return 0 ;;
    esac
    [[ "$ext" == "md" && "$target" == "markdown" || "$ext" == "$target" ]] && {
      warn "Source and target formats are the same."; return 1;
    }
  fi
  stem="${src%.*}"
  case "$target" in markdown) output="${stem}_converted.md" ;; *) output="${stem}_converted.$target" ;; esac
  suffix=1
  while [[ -e "$output" ]]; do
    case "$target" in markdown) output="${stem}_converted_${suffix}.md" ;; *) output="${stem}_converted_${suffix}.$target" ;; esac
    ((suffix += 1))
  done
  if [[ "$ext" == "pdf" ]]; then
    tmp="$(mktemp "${TMPDIR:-$PREFIX/tmp}/cyberforge-pdf-text.XXXXXX")" || {
      err "Could not create temporary extraction file."; return 1;
    }
    if ! pdftotext -layout "$src" "$tmp"; then
      rm -f "$tmp"; err "Could not extract selectable text from this PDF."; return 1
    fi
    if [[ "$target" == "txt" ]]; then
      cp "$tmp" "$output"; rc=$?
    else
      pandoc -f plain -t "$target" -o "$output" "$tmp"; rc=$?
    fi
    rm -f "$tmp"
  else
    case "$ext" in
      docx) from="docx" ;;
      odt) from="odt" ;;
      epub) from="epub" ;;
      html|htm) from="html" ;;
      md|txt) from="markdown" ;;
      rtf) from="rtf" ;;
    esac
    pandoc -f "$from" -t "$target" -o "$output" "$src"
    rc=$?
  fi
  if (( rc == 0 )) && [ -s "$output" ]; then
    ok "Converted file saved: $output"
    info "Original document was not modified."
    scan_media "$(dirname "$output")"
  else
    rm -f -- "$output"
    err "Conversion failed. Original document remains unchanged."
    return 1
  fi
}
