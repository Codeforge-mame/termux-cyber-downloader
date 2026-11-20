#!/data/data/com.termux/files/usr/bin/bash
# Read-only local filename search for CyberForge Document Manager.

DOC_SEARCH_LABELS=()
DOC_SEARCH_PATHS=()
DOC_SEARCH_WRITABLE=()
DOC_SEARCH_BLOCKED_LABELS=()
DOC_SEARCH_BLOCKED_PATHS=()

document_search_add_root() {
  local label="$1" path="$2" resolved existing probe writable=0
  [ -d "$path" ] || return 0
  resolved="$(readlink -f "$path" 2>/dev/null)"
  [ -n "$resolved" ] || resolved="$path"
  for existing in "${DOC_SEARCH_PATHS[@]}"; do
    [ "$existing" = "$resolved" ] && return 0
  done
  # Probe actual access: Android scoped storage can deny access despite -r/-x.
  if ! ls -A -- "$resolved" >/dev/null 2>&1; then
    DOC_SEARCH_BLOCKED_PATHS+=("$resolved")
    DOC_SEARCH_BLOCKED_LABELS+=("$label")
    return 0
  fi
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
  DOC_SEARCH_BLOCKED_LABELS=()
  DOC_SEARCH_BLOCKED_PATHS=()
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

  # Android may deny listing /storage even when a known FUSE volume path
  # is accessible. Read mount tables to discover /storage/<volume-id> paths.
  # Do not scan /mnt/media_rw: it is the privileged backing mount and is
  # commonly inaccessible to Termux even when the FUSE path is writable.
  while read -r device mountpoint fstype options rest; do
    [[ "$mountpoint" == /storage/* ]] || continue
    name="${mountpoint##*/}"
    case "$name" in emulated|self|media_rw|user|pass_through) continue ;; esac
    document_search_add_root "SD / external storage: $name" "$mountpoint"
  done < /proc/mounts

  # Keep direct FUSE-path globbing as a fallback on Android versions where
  # /storage can be enumerated normally.
  for path in /storage/*; do
    [ -d "$path" ] || continue
    name="${path##*/}"
    case "$name" in emulated|self|media_rw|user|pass_through) continue ;; esac
    document_search_add_root "SD / external storage: $name" "$path"
  done
}
# After conversion, let the user keep the default output or move it to
# a detected writable SD card / USB volume. The source file is never touched.
document_offer_conversion_destination() {
  local converted="$1" choice idx root target_dir target_file base stem ext suffix temp
  local -a removable_paths=() removable_labels=()
  [ -f "$converted" ] || return 1

  document_search_discover_roots
  local internal_root
  internal_root="$(readlink -f "$HOME/storage/shared" 2>/dev/null)"
  for idx in "${!DOC_SEARCH_PATHS[@]}"; do
    [[ "${DOC_SEARCH_WRITABLE[$idx]}" == "1" ]] || continue
    root="${DOC_SEARCH_PATHS[$idx]}"
    [[ -n "$internal_root" && "$root" == "$internal_root" ]] && continue
    # Only removable-volume entries are offered, not another alias of internal storage.
    case "${DOC_SEARCH_LABELS[$idx]}" in
      "Removable storage:"*|"SD / external storage:"*)
        removable_paths+=("$root")
        removable_labels+=("${DOC_SEARCH_LABELS[$idx]}")
        ;;
    esac
  done

  printf '\nCONVERTED FILE DESTINATION\n'
  printf '%s\n' " 1) Keep in Documents/Converted"
  if (( ${#removable_paths[@]} > 0 )); then
    printf '%s\n' " 2) Save to SD card / USB drive"
  fi
  printf ' 0) Cancel destination change (keep default)\n'
  local allowed="1 0"
  (( ${#removable_paths[@]} > 0 )) && allowed="1 2 0"
  ask_choice "Choose where to keep the converted file: " choice "$allowed" || {
    info "Keeping converted file in Documents/Converted."
    return 0
  }
  case "$choice" in
    0|1)
      info "Converted file kept in: ${converted%/*}"
      scan_media "${converted%/*}"
      return 0
      ;;
    2) ;;
  esac

  printf '\nAVAILABLE REMOVABLE DESTINATIONS\n'
  allowed="0"
  for idx in "${!removable_paths[@]}"; do
    printf ' %s) %s\n    %s\n' "$((idx + 1))" "${removable_labels[$idx]}" "${removable_paths[$idx]}"
    allowed+=" $((idx + 1))"
  done
  printf ' 0) Keep default destination\n'
  ask_choice "Choose SD / USB volume: " choice "$allowed" || {
    info "Keeping converted file in Documents/Converted."
    return 0
  }
  [[ "$choice" == "0" ]] && { info "Keeping converted file in Documents/Converted."; return 0; }

  root="${removable_paths[$((choice - 1))]}"
  target_dir="$root/CyberForge/Converted"
  mkdir -p -- "$target_dir" 2>/dev/null || {
    warn "Could not create a Converted folder on this volume. The file remains in Documents/Converted."
    return 0
  }
  temp="$(mktemp "$target_dir/.cyberforge-transfer.XXXXXX" 2>/dev/null)" || {
    warn "The selected volume is not writable. The file remains in Documents/Converted."
    return 0
  }
  base="${converted##*/}"
  target_file="$target_dir/$base"
  if [[ -e "$target_file" ]]; then
    stem="${base%.*}"; ext=""
    [[ "$base" == *.* && "$base" != .* ]] && ext=". ${base##*.}"
    ext="${ext// /}"
    suffix=1
    while [[ -e "$target_dir/$stem (copy $suffix)$ext" ]]; do ((suffix += 1)); done
    target_file="$target_dir/$stem (copy $suffix)$ext"
  fi

  if cp -p -- "$converted" "$temp" 2>/dev/null && cmp -s -- "$converted" "$temp" &&
     mv -- "$temp" "$target_file" 2>/dev/null; then
    if rm -- "$converted" 2>/dev/null; then
      ok "Converted file saved to: $target_file"
      scan_media "$target_dir"
    else
      warn "Verified copy saved to $target_file, but the default copy could not be removed."
      rm -f -- "$temp" 2>/dev/null
    fi
  else
    rm -f -- "$temp" 2>/dev/null
    warn "Could not transfer the converted file. It remains in Documents/Converted."
  fi
  return 0
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
    ok "Recognized file type."
    info "Use the Convert action after selecting this file. The original remains unchanged."
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
  local can_convert=0 can_clean=0
  for src in "${selected[@]}"; do
    if document_file_is_convertible "$src"; then can_convert=1; fi
    if document_file_metadata_supported "$src"; then can_clean=1; fi
  done
  local operation_choices="1 2 3 0"
  printf '%s\n' " 1) Copy" " 2) Move" " 3) Delete"
  if (( can_convert )); then
    printf '%s\n' " 4) Convert supported selected files"
    operation_choices="1 2 3 4 0"
  fi
  if (( ${#selected[@]} == 1 )); then
    printf '%s\n' " 5) Read / open selected file"
    operation_choices="$operation_choices 5"
  fi
  if (( can_clean )); then
    printf '%s\n' " 6) Remove private metadata (create clean copies)"
    operation_choices="$operation_choices 6"
  fi
  printf '%s\n' " 0) Cancel"
  ask_choice "Choose operation: " action "$operation_choices" || return 1

  case "$action" in
    0|"") return 0 ;;
    4)
      local convert_count=0 convert_failed=0
      for src in "${selected[@]}"; do
        if document_file_is_convertible "$src"; then
          if document_convert_file "$src"; then ((convert_count += 1)); else ((convert_failed += 1)); fi
        else
          warn "Skipped unsupported file: ${src##*/}"
          ((convert_failed += 1))
        fi
      done
      printf '\nConversion summary: %s converted, %s skipped/failed.\n' "$convert_count" "$convert_failed"
      ;;
    5)
      for src in "${selected[@]}"; do document_read_file "$src" || warn "Could not read/open: ${src##*/}"; printf '\n'; done
      ;;
    6)
      printf '\nMetadata cleaning creates new copies in Documents/PrivacyCleaned. Originals are never changed.\n'
      local clean_count=0 clean_failed=0
      for src in "${selected[@]}"; do
        if document_file_metadata_supported "$src"; then
          if document_remove_private_metadata "$src"; then ((clean_count += 1)); else ((clean_failed += 1)); fi
        else
          warn "Skipped unsupported metadata format: ${src##*/}"
          ((clean_failed += 1))
        fi
      done
      printf '\nMetadata cleaning summary: %s created, %s skipped/failed.\n' "$clean_count" "$clean_failed"
      ;;
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
      printf '\nWRITABLE DESTINATION LOCATIONS\n'
      for idx in "${!writable_paths[@]}"; do
        printf ' %s) %s\n    %s\n' "$((idx + 1))" "${writable_labels[$idx]}" "${writable_paths[$idx]}"
      done
      printf ' 0) Cancel\n'
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

  if (( ${#DOC_SEARCH_BLOCKED_PATHS[@]} > 0 )); then
    warn "Some mounted storage locations were detected but Termux cannot read them:"
    for index in "${!DOC_SEARCH_BLOCKED_PATHS[@]}"; do
      printf ' - %s: %s\n' "${DOC_SEARCH_BLOCKED_LABELS[$index]}" "${DOC_SEARCH_BLOCKED_PATHS[$index]}"
    done
    info "Check Android app storage permissions. Android scoped storage may still block removable volumes."
  fi
  if (( ${#DOC_SEARCH_PATHS[@]} == 0 )); then
    err "No readable shared or removable storage was detected."
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
  if (( ${#DOC_SEARCH_BLOCKED_PATHS[@]} > 0 )); then
    warn "Detected storage that Termux cannot read:"
    for index in "${!DOC_SEARCH_BLOCKED_PATHS[@]}"; do
      printf ' - %s: %s\n' "${DOC_SEARCH_BLOCKED_LABELS[$index]}" "${DOC_SEARCH_BLOCKED_PATHS[$index]}"
    done
    info "Check Android storage permission; some removable volumes may be restricted by scoped storage."
  fi
  if (( ${#DOC_SEARCH_PATHS[@]} == 0 )); then
    err "No readable shared or removable storage was detected."
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


# Image conversion uses ImageMagick; only common raster formats are offered.
document_file_is_image_convertible() {
  local ext="$1"
  ext="${ext##*.}"
  ext="${ext,,}"
  case "$ext" in jpg|jpeg|png|webp|bmp|gif|tif|tiff) return 0 ;; *) return 1 ;; esac
}

document_convert_image_file() {
  local src="$1" choice ext target output_dir filename stem output suffix probe image_cmd rc idx allowed="0"
  local -a targets=()
  [ -f "$src" ] && [ -r "$src" ] || { err "Selected image is not readable: $src"; return 1; }
  if command -v magick >/dev/null 2>&1; then image_cmd="magick"
  elif command -v convert >/dev/null 2>&1; then image_cmd="convert"
  else warn "Image conversion requires ImageMagick: pkg install imagemagick"; return 1
  fi

  ext="${src##*.}"; ext="${ext,,}"
  for target in jpg png webp bmp gif tiff pdf; do
    case "$ext:$target" in
      jpg:jpg|jpeg:jpg|jpeg:jpeg|png:png|webp:webp|bmp:bmp|gif:gif|tif:tiff|tiff:tiff) continue ;;
    esac
    targets+=("$target")
  done
  (( ${#targets[@]} > 0 )) || { warn "No different output format is available for this image."; return 1; }

  printf '\nAVAILABLE OUTPUT FORMATS\n'
  for idx in "${!targets[@]}"; do
    printf ' %s) %s\n' "$((idx + 1))" "${targets[$idx]^^}"
    allowed+=" $((idx + 1))"
  done
  printf ' 0) Cancel\n'
  ask_choice "Convert image ${src##*/} to: " choice "$allowed" || return 1
  [[ "$choice" == "0" ]] && return 0
  target="${targets[$((choice - 1))]}"

  output_dir="$DOC_DIR/Converted"
  mkdir -p -- "$output_dir" 2>/dev/null || { err "Cannot create the Converted folder: $output_dir"; return 1; }
  probe="$(mktemp "$output_dir/.cyberforge-image.XXXXXX" 2>/dev/null)" || { err "Converted folder is not writable: $output_dir"; return 1; }
  rm -f -- "$probe"

  filename="${src##*/}"; filename="${filename%.*}"
  stem="$output_dir/$filename"
  output="${stem}_converted.$target"; suffix=1
  while [[ -e "$output" ]]; do output="${stem}_converted_$suffix.$target"; ((suffix += 1)); done

  "$image_cmd" "$src" -quality 90 "$output"
  rc=$?
  # Some ImageMagick builds disable PDF writing by policy. Pillow is a safe
  # fallback for single-image PDF output when it is already installed.
  if (( rc != 0 )) && [[ "$target" == "pdf" ]] && command -v python >/dev/null 2>&1; then
    rm -f -- "$output"
    python - "$src" "$output" <<'PY'
import sys
try:
    from PIL import Image
except ImportError:
    raise SystemExit(1)
source, destination = sys.argv[1], sys.argv[2]
with Image.open(source) as image:
    image.convert("RGB").save(destination, "PDF", resolution=150)
PY
    rc=$?
  fi
  if (( rc == 0 )) && [ -s "$output" ]; then
    info "Original image was not modified."
    document_offer_conversion_destination "$output"
    [[ -f "$output" ]] && ok "Converted image saved: $output"
    return 0
  fi
  rm -f -- "$output"
  err "Image conversion failed. This ImageMagick build may not support the source or target format."
  return 1
}
# Read text documents in the terminal and open binary/media files with Android.
document_read_file() {
  local src="$1" ext tmp rc
  [ -f "$src" ] && [ -r "$src" ] || { err "Selected file is not readable: $src"; return 1; }
  ext="$src"; ext="${ext##*.}"; ext="${ext,,}"
  banner "READ FILE"
  printf 'File: %s\n\n' "${src##*/}"
  case "$ext" in
    txt|md|csv|html|htm|xml|json|log|sh|py|js|ts|css|yaml|yml|ini|conf)
      sed -n '1,200p' -- "$src"; printf '\n'; info "Showing the first 200 lines." ;;
    pdf)
      command -v pdftotext >/dev/null 2>&1 || { warn "Reading PDF text requires Poppler: pkg install poppler"; return 1; }
      tmp="$(mktemp "${TMPDIR:-$PREFIX/tmp}/cyberforge-read.XXXXXX")" || return 1
      if pdftotext -layout "$src" "$tmp"; then
        sed -n '1,200p' "$tmp"; info "Showing the first 200 lines of selectable PDF text. Scanned pages need OCR, which is not included."; rc=0
      else err "Could not extract text from this PDF."; rc=1
      fi
      rm -f "$tmp"; return "$rc" ;;
    docx|odt|epub|rtf)
      command -v pandoc >/dev/null 2>&1 || { warn "Reading this document requires Pandoc: pkg install pandoc"; return 1; }
      tmp="$(mktemp "${TMPDIR:-$PREFIX/tmp}/cyberforge-read.XXXXXX")" || return 1
      if pandoc -t plain -o "$tmp" "$src" 2>/dev/null; then
        sed -n '1,200p' "$tmp"
        info "Showing up to the first 200 lines."
        rc=0
      else
        err "Pandoc could not read this document."
        rc=1
      fi
      rm -f "$tmp"
      return "$rc" ;;
    *)
      if command -v termux-open >/dev/null 2>&1; then termux-open "$src"
      else warn "No terminal reader is available for this file type. Install Termux:API to open it with Android."; return 1
      fi ;;
  esac
}

# Validate conversion outputs before reporting success.
document_validate_converted_output() {
  local output="$1" format="${2,,}"
  [[ -s "$output" ]] || { err "Conversion produced an empty output file."; return 1; }
  case "$format" in
    docx|xlsx|pptx|odt|epub)
      python - "$output" "$format" <<'PY'
import sys, zipfile
path, fmt = sys.argv[1:3]
required = {
    "docx": {"[Content_Types].xml", "word/document.xml"},
    "xlsx": {"[Content_Types].xml", "xl/workbook.xml"},
    "pptx": {"[Content_Types].xml", "ppt/presentation.xml"},
    "odt": {"mimetype", "content.xml"},
    "epub": {"mimetype", "META-INF/container.xml"},
}[fmt]
try:
    with zipfile.ZipFile(path) as archive:
        bad = archive.testzip()
        if bad or not required.issubset(set(archive.namelist())):
            raise ValueError(f"Invalid {fmt.upper()} package")
except Exception as exc:
    print(f"Output validation failed: {exc}", file=sys.stderr)
    sys.exit(1)
PY
      return $? ;;
    pdf)
      head -c 5 "$output" 2>/dev/null | grep -q '^%PDF-' || { err "Output does not have a valid PDF signature."; return 1; } ;;
    jpg|jpeg|png|webp|bmp|gif|tif|tiff)
      if command -v magick >/dev/null 2>&1; then magick identify "$output" >/dev/null 2>&1 || return 1
      elif command -v identify >/dev/null 2>&1; then identify "$output" >/dev/null 2>&1 || return 1
      fi ;;
  esac
  return 0
}

# Metadata cleaning writes a separate sanitized copy; the source is untouched.
document_file_metadata_supported() {
  local ext="${1##*.}"; ext="${ext,,}"
  case "$ext" in jpg|jpeg|png|webp|bmp|gif|tif|tiff|pdf|docx|xlsx|pptx|odt|epub) return 0 ;; *) return 1 ;; esac
}

document_remove_private_metadata() {
  local src="$1" ext output_dir filename output suffix rc=1 probe
  [[ -f "$src" && -r "$src" ]] || { err "Selected file is not readable: $src"; return 1; }
  document_file_metadata_supported "$src" || { warn "Unsupported metadata format: ${src##*/}"; return 1; }
  ext="${src##*.}"; ext="${ext,,}"
  output_dir="$DOC_DIR/PrivacyCleaned"
  mkdir -p -- "$output_dir" 2>/dev/null || { err "Cannot create PrivacyCleaned folder."; return 1; }
  probe="$(mktemp "$output_dir/.cyberforge-private.XXXXXX" 2>/dev/null)" || { err "PrivacyCleaned folder is not writable."; return 1; }
  rm -f -- "$probe"
  filename="${src##*/}"; filename="${filename%.*}"
  output="$output_dir/${filename}_metadata_removed.$ext"
  suffix=1
  while [[ -e "$output" ]]; do output="$output_dir/${filename}_metadata_removed_$suffix.$ext"; ((suffix += 1)); done

  case "$ext" in
    docx|xlsx|pptx|odt|epub)
      python - "$src" "$output" "$ext" <<'PY'
import sys, zipfile
import xml.etree.ElementTree as ET
source, destination, fmt = sys.argv[1:4]
def local(tag):
    return tag.rsplit("}", 1)[-1].lower()
try:
    with zipfile.ZipFile(source, "r") as src, zipfile.ZipFile(destination, "w") as dst:
        for info in src.infolist():
            name = info.filename
            data = src.read(name)
            lower = name.lower()
            if lower in ("docprops/core.xml", "docprops/app.xml", "docprops/custom.xml", "meta.xml"):
                root = ET.fromstring(data)
                root.clear()
                data = ET.tostring(root, encoding="utf-8", xml_declaration=True)
            elif fmt == "epub" and lower.endswith(".opf"):
                root = ET.fromstring(data)
                for parent in root.iter():
                    for child in list(parent):
                        tag = local(child.tag)
                        prop = child.attrib.get("property", "").lower()
                        if tag in {"creator", "contributor", "publisher", "rights", "date"}:
                            parent.remove(child)
                        elif tag == "meta" and prop in {"dcterms:modified", "calibre:timestamp"}:
                            parent.remove(child)
                data = ET.tostring(root, encoding="utf-8", xml_declaration=True)
            dst.writestr(info, data)
except Exception as exc:
    print(f"Metadata cleaning failed: {exc}", file=sys.stderr)
    sys.exit(1)
PY
      rc=$? ;;
    pdf)
      if command -v exiftool >/dev/null 2>&1; then exiftool -all= -o "$output" "$src" >/dev/null 2>&1 && rc=0
      else warn "PDF metadata cleaning requires ExifTool: pkg install exiftool"; fi ;;
    *)
      if command -v exiftool >/dev/null 2>&1; then exiftool -all= -o "$output" "$src" >/dev/null 2>&1 && rc=0
      elif command -v magick >/dev/null 2>&1; then magick "$src" -strip "$output" >/dev/null 2>&1 && rc=0
      elif command -v convert >/dev/null 2>&1; then convert "$src" -strip "$output" >/dev/null 2>&1 && rc=0
      else warn "Image metadata cleaning needs ExifTool or ImageMagick."; fi ;;
  esac

  if (( rc == 0 )) && document_validate_converted_output "$output" "$target"; then
    info "A metadata-cleaned copy was created. The original file was not changed."
    ok "Sanitized copy: $output"
    if command -v termux-media-scan >/dev/null 2>&1; then termux-media-scan "$output" >/dev/null 2>&1 || true; fi
    return 0
  fi
  rm -f -- "$output"
  err "Could not create a verified metadata-cleaned copy. Original remains unchanged."
  return 1
}

# Supported document conversions. OCR and scanned-PDF conversion are intentionally excluded.
document_file_is_convertible() {
  local ext="$1"
  ext="${ext##*.}"
  ext="${ext,,}"
  case "$ext" in
    docx|odt|epub|html|htm|md|txt|rtf|pdf|jpg|jpeg|png|webp|bmp|gif|tif|tiff|csv|xls|xlsx|ods|ppt|pptx|odp)
      return 0 ;;
    *) return 1 ;;
  esac
}

# Spreadsheet conversion: CSV <-> XLSX with openpyxl, or use LibreOffice
# when available for XLS/XLSX/ODS and PDF interchange.
document_convert_spreadsheet_file() {
  local src="$1" ext="${1##*.}" choice target output_dir filename output suffix probe
  local office_cmd="" rc=1 sheet
  local -a targets=()
  ext="${ext,,}"
  if command -v libreoffice >/dev/null 2>&1; then office_cmd="libreoffice"
  elif command -v soffice >/dev/null 2>&1; then office_cmd="soffice"
  fi

  if [[ -n "$office_cmd" ]]; then
    for target in csv xlsx xls ods pdf; do
      [[ "$target" == "$ext" ]] || targets+=("$target")
    done
  elif command -v python >/dev/null 2>&1; then
    if ! python -c 'import openpyxl' >/dev/null 2>&1; then
      warn "CSV/XLSX conversion needs openpyxl: python -m pip install openpyxl"
      return 1
    fi
    case "$ext" in
      csv) targets=(xlsx) ;;
      xlsx) targets=(csv) ;;
      *) warn "This spreadsheet format needs LibreOffice (XLS/ODS support)."; return 1 ;;
    esac
  else
    warn "Spreadsheet conversion needs LibreOffice or Python with openpyxl."
    return 1
  fi

  printf '\nAVAILABLE SPREADSHEET OUTPUT FORMATS\n'
  for i in "${!targets[@]}"; do printf ' %s) %s\n' "$((i + 1))" "${targets[$i]^^}"; done
  printf ' 0) Cancel\n'
  local allowed="0"
  for i in "${!targets[@]}"; do allowed+=" $((i + 1))"; done
  ask_choice "Convert ${src##*/} to: " choice "$allowed" || return 1
  [[ "$choice" == "0" ]] && return 0
  target="${targets[$((choice - 1))]}"

  output_dir="$DOC_DIR/Converted"
  mkdir -p -- "$output_dir" 2>/dev/null || { err "Cannot create Converted folder."; return 1; }
  probe="$(mktemp "$output_dir/.cyberforge-sheet.XXXXXX" 2>/dev/null)" || { err "Converted folder is not writable."; return 1; }
  rm -f -- "$probe"
  filename="${src##*/}"; filename="${filename%.*}"
  output="$output_dir/${filename}_converted.$target"
  suffix=1
  while [[ -e "$output" ]]; do output="$output_dir/${filename}_converted_$suffix.$target"; ((suffix += 1)); done

  if [[ -n "$office_cmd" ]]; then
    local tmpdir generated
    tmpdir="$(mktemp -d "$output_dir/.cyberforge-office.XXXXXX" 2>/dev/null)" || return 1
    if "$office_cmd" --headless --convert-to "$target" --outdir "$tmpdir" "$src" >/dev/null 2>&1; then
      generated="$tmpdir/${filename}.$target"
      if [[ -s "$generated" ]]; then mv -- "$generated" "$output" && rc=0; fi
    fi
    rm -rf -- "$tmpdir"
  elif [[ "$ext" == "csv" && "$target" == "xlsx" ]]; then
    python - "$src" "$output" <<'PY'
import csv, sys
from openpyxl import Workbook
source, destination = sys.argv[1:3]
book = Workbook()
sheet = book.active
with open(source, "r", encoding="utf-8-sig", newline="") as handle:
    sample = handle.read(8192)
    handle.seek(0)
    try:
        dialect = csv.Sniffer().sniff(sample)
    except csv.Error:
        dialect = csv.excel
    for row in csv.reader(handle, dialect):
        sheet.append(row)
book.save(destination)
PY
    rc=$?
  elif [[ "$ext" == "xlsx" && "$target" == "csv" ]]; then
    local -a sheet_names=()
    mapfile -t sheet_names < <(python - "$src" <<'PY'
import sys
from openpyxl import load_workbook
book = load_workbook(sys.argv[1], read_only=True, data_only=True)
for name in book.sheetnames:
    print(name)
book.close()
PY
)
    if (( ${#sheet_names[@]} == 0 )); then err "No readable worksheet was found."; return 1; fi
    if (( ${#sheet_names[@]} > 1 )); then
      printf '\nWORKSHEETS\n'
      for i in "${!sheet_names[@]}"; do printf ' %s) %s\n' "$((i + 1))" "${sheet_names[$i]}"; done
      local sheet_allowed="0"
      for i in "${!sheet_names[@]}"; do sheet_allowed+=" $((i + 1))"; done
      ask_choice "Choose worksheet to export: " choice "$sheet_allowed" || return 1
      [[ "$choice" == "0" ]] && return 0
      sheet="${sheet_names[$((choice - 1))]}"
    else
      sheet="${sheet_names[0]}"
    fi
    python - "$src" "$output" "$sheet" <<'PY'
import csv, sys
from openpyxl import load_workbook
source, destination, sheet_name = sys.argv[1:4]
book = load_workbook(source, read_only=True, data_only=True)
sheet = book[sheet_name]
with open(destination, "w", encoding="utf-8-sig", newline="") as handle:
    writer = csv.writer(handle)
    for row in sheet.iter_rows(values_only=True):
        writer.writerow(["" if value is None else value for value in row])
book.close()
PY
    rc=$?
  fi

  if (( rc == 0 )) && document_validate_converted_output "$output" "$target"; then
    info "Spreadsheet converted. The original workbook/file was not modified."
    document_offer_conversion_destination "$output"
    [[ -f "$output" ]] && ok "Converted file saved: $output"
    return 0
  fi
  rm -f -- "$output"
  err "Spreadsheet conversion failed. The source file remains unchanged."
  return 1
}

# Presentation conversion uses LibreOffice for real format conversion.
# Without it, python-pptx can export PPTX slide text to a plain TXT file.
document_convert_presentation_file() {
  local src="$1" ext="${1##*.}" choice target output_dir filename output suffix probe
  local office_cmd="" rc=1
  local -a targets=()
  ext="${ext,,}"
  if command -v libreoffice >/dev/null 2>&1; then office_cmd="libreoffice"
  elif command -v soffice >/dev/null 2>&1; then office_cmd="soffice"
  fi

  if [[ -n "$office_cmd" ]]; then
    for target in pptx odp ppt pdf; do
      [[ "$target" == "$ext" ]] || targets+=("$target")
    done
  elif [[ "$ext" == "pptx" ]] && command -v python >/dev/null 2>&1 &&
       python -c 'import pptx' >/dev/null 2>&1; then
    targets=(txt)
  else
    warn "Presentation conversion needs LibreOffice. PPTX-to-TXT also works with: python -m pip install python-pptx"
    return 1
  fi

  printf '\nAVAILABLE PRESENTATION OUTPUT FORMATS\n'
  for i in "${!targets[@]}"; do printf ' %s) %s\n' "$((i + 1))" "${targets[$i]^^}"; done
  printf ' 0) Cancel\n'
  local allowed="0"
  for i in "${!targets[@]}"; do allowed+=" $((i + 1))"; done
  ask_choice "Convert ${src##*/} to: " choice "$allowed" || return 1
  [[ "$choice" == "0" ]] && return 0
  target="${targets[$((choice - 1))]}"

  output_dir="$DOC_DIR/Converted"
  mkdir -p -- "$output_dir" 2>/dev/null || { err "Cannot create Converted folder."; return 1; }
  probe="$(mktemp "$output_dir/.cyberforge-presentation.XXXXXX" 2>/dev/null)" || { err "Converted folder is not writable."; return 1; }
  rm -f -- "$probe"
  filename="${src##*/}"; filename="${filename%.*}"
  output="$output_dir/${filename}_converted.$target"
  suffix=1
  while [[ -e "$output" ]]; do output="$output_dir/${filename}_converted_$suffix.$target"; ((suffix += 1)); done

  if [[ -n "$office_cmd" ]]; then
    local tmpdir generated
    tmpdir="$(mktemp -d "$output_dir/.cyberforge-office.XXXXXX" 2>/dev/null)" || return 1
    if "$office_cmd" --headless --convert-to "$target" --outdir "$tmpdir" "$src" >/dev/null 2>&1; then
      generated="$tmpdir/${filename}.$target"
      if [[ -s "$generated" ]]; then mv -- "$generated" "$output" && rc=0; fi
    fi
    rm -rf -- "$tmpdir"
  else
    # PPTX is a ZIP package. Extract slide text with Python's standard library,
    # avoiding python-pptx/lxml compilation on Termux.
    python - "$src" "$output" <<'PY'
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

source, destination = sys.argv[1:3]
try:
    with zipfile.ZipFile(source) as package:
        slides = [
            name for name in package.namelist()
            if re.fullmatch(r"ppt/slides/slide\d+\.xml", name)
        ]
        slides.sort(key=lambda name: int(re.search(r"slide(\d+)\.xml$", name).group(1)))
        if not slides:
            raise ValueError("No slide XML files were found")
        with open(destination, "w", encoding="utf-8") as output_file:
            for number, slide_name in enumerate(slides, 1):
                root = ET.fromstring(package.read(slide_name))
                texts = [
                    node.text.strip()
                    for node in root.iter()
                    if node.tag.endswith("}t") and node.text and node.text.strip()
                ]
                output_file.write(f"Slide {number}\n")
                if texts:
                    output_file.write("\n".join(texts) + "\n")
                output_file.write("\n")
except Exception as exc:
    print(f"PPTX text extraction failed: {exc}", file=sys.stderr)
    sys.exit(1)
PY
    rc=$?
  fi

  if (( rc == 0 )) && document_validate_converted_output "$output" "$target"; then
    info "Presentation converted. The original file was not modified."
    document_offer_conversion_destination "$output"
    [[ -f "$output" ]] && ok "Converted file saved: $output"
    return 0
  fi
  rm -f -- "$output"
  err "Presentation conversion failed. The source file remains unchanged."
  return 1
}

document_convert_file() {
  local src="$1" choice ext target from output stem suffix tmp rc output_dir filename probe tmpdir pdf_engine candidate idx allowed="0"
  local -a targets=()
  [ -f "$src" ] && [ -r "$src" ] || { err "Selected file is not readable: $src"; return 1; }
  document_file_is_convertible "$src" || { warn "Conversion is not supported for: $src"; return 1; }
  if document_file_is_image_convertible "$src"; then document_convert_image_file "$src"; return $?; fi
  ext="$src"; ext="${ext##*.}"; ext="${ext,,}"
  case "$ext" in
    csv|xls|xlsx|ods) document_convert_spreadsheet_file "$src"; return $? ;;
    ppt|pptx|odp) document_convert_presentation_file "$src"; return $? ;;
  esac
  if [[ "$ext" == "pdf" ]]; then
    command -v pdftotext >/dev/null 2>&1 || { warn "PDF extraction requires Poppler: pkg install poppler"; info "Scanned PDFs are not supported without OCR."; return 1; }
    targets=(txt docx odt html markdown)
    printf '\nAVAILABLE OUTPUT FORMATS\n'
    for idx in "${!targets[@]}"; do printf ' %s) %s\n' "$((idx + 1))" "${targets[$idx]^^}"; allowed+=" $((idx + 1))"; done
  else
    command -v pandoc >/dev/null 2>&1 || { warn "Install Pandoc: pkg install pandoc"; return 1; }
    for target in docx odt epub html markdown rtf pdf; do
      case "$ext:$target" in
        docx:docx|odt:odt|epub:epub|html:html|htm:html|md:markdown|rtf:rtf) continue ;;
      esac
      targets+=("$target")
    done
    (( ${#targets[@]} > 0 )) || { warn "No different output format is available."; return 1; }
    printf '\nAVAILABLE OUTPUT FORMATS\n'
    for idx in "${!targets[@]}"; do printf ' %s) %s\n' "$((idx + 1))" "${targets[$idx]^^}"; allowed+=" $((idx + 1))"; done
  fi
  printf ' 0) Cancel\n'
  ask_choice "Convert ${src##*/} to: " choice "$allowed" || return 1
  [[ "$choice" == "0" ]] && return 0
  target="${targets[$((choice - 1))]}"

  if [[ "$target" == "pdf" ]]; then
    pdf_engine=""
    for candidate in tectonic xelatex lualatex pdflatex weasyprint wkhtmltopdf typst; do
      if command -v "$candidate" >/dev/null 2>&1; then pdf_engine="$candidate"; break; fi
    done
    if [[ -z "$pdf_engine" ]]; then
      warn "PDF output needs a Pandoc PDF engine (for example Tectonic, XeLaTeX, or WeasyPrint)."
      info "Install and configure a supported PDF engine, then retry. The source file is unchanged."
      return 1
    fi
  fi

  output_dir="$DOC_DIR/Converted"
  mkdir -p -- "$output_dir" 2>/dev/null || { err "Cannot create the Converted folder: $output_dir"; return 1; }
  probe="$(mktemp "$output_dir/.cyberforge-convert.XXXXXX" 2>/dev/null)" || { err "Converted folder is not writable: $output_dir"; return 1; }
  rm -f -- "$probe"

  filename="${src##*/}"; filename="${filename%.*}"
  stem="$output_dir/$filename"
  if [[ "$target" == "markdown" ]]; then output="${stem}_converted.md"; else output="${stem}_converted.$target"; fi
  suffix=1
  while [[ -e "$output" ]]; do
    if [[ "$target" == "markdown" ]]; then output="${stem}_converted_$suffix.md"; else output="${stem}_converted_$suffix.$target"; fi
    ((suffix += 1))
  done

  if [[ "$ext" == "pdf" ]]; then
    tmpdir="${TMPDIR:-$PREFIX/tmp}"
    tmp="$(mktemp "$tmpdir/cyberforge-pdf-text.XXXXXX")" || { err "Could not create temporary extraction file."; return 1; }
    if ! pdftotext -layout "$src" "$tmp"; then rm -f "$tmp"; err "Could not extract selectable PDF text."; return 1; fi
    if [[ "$target" == "txt" ]]; then
      cp -- "$tmp" "$output"; rc=$?
    else
      pandoc -f markdown -t "$target" -o "$output" "$tmp"; rc=$?
    fi
    rm -f "$tmp"
  else
    case "$ext" in
      docx) from="docx" ;; odt) from="odt" ;; epub) from="epub" ;;
      html|htm) from="html" ;; md) from="markdown" ;; txt) from="plain" ;; rtf) from="rtf" ;;
    esac
    if [[ "$target" == "pdf" ]]; then
      pandoc -f "$from" --pdf-engine="$pdf_engine" -o "$output" "$src"; rc=$?
    else
      pandoc -f "$from" -t "$target" -o "$output" "$src"; rc=$?
    fi
  fi

  if (( rc == 0 )) && [ -s "$output" ]; then
    info "Original document was not modified."
    document_offer_conversion_destination "$output"
    [[ -f "$output" ]] && ok "Converted file saved: $output"
    return 0
  fi
  rm -f -- "$output"
  err "Conversion failed. Original document remains unchanged."
  return 1
}
