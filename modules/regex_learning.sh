#!/data/data/com.termux/files/usr/bin/bash
# Interactive Bash regular-expression lessons for CyberForge.

regex_learning_pause() {
  local unused
  read -r -p "Press Enter to continue..." unused
}

regex_learning_examples() {
  local level="$1"
  banner "$level REGEX EXAMPLES"
  if [[ "$level" == "BASIC" ]]; then
    cat <<'LESSON'
BASIC PATTERNS (Bash uses POSIX extended regular expressions)

Pattern             Meaning                         Examples
^[0-9]+$             One or more digits only        42
^[a-z]+$             One or more lowercase letters  hello
^[A-Z]+$             One or more uppercase letters  HELLO
^[a-zA-Z]+$          Letters only                   Mame
^[0-9]{4}$           Exactly four digits            2026
^[a-zA-Z0-9_]{3,20}$ Username: 3 to 20 characters  mame_23

CORE SYMBOLS
^       Start of the string
$       End of the string
[abc]   Any one listed character
[a-z]   Any character in a range
[0-9]   Any digit
+       One or more
*       Zero or more
?       Zero or one
{n}     Exactly n repetitions
{n,m}   Between n and m repetitions

Remember: anchors ^ and $ make the whole input match the pattern.
Without them, a pattern can match only part of a string.
LESSON
  else
    cat <<'LESSON'
ADVANCED PATTERNS (Bash uses POSIX extended regular expressions)

Pattern                         Meaning
^[a-zA-Z][a-zA-Z0-9_]{2,15}$     Letter first, then 2-15 allowed characters
^(cat|dog)$                     Exactly "cat" or "dog"
^[0-9]{1,3}(,[0-9]{3})*$         Grouped number such as 1,234 or 12,345
^[[:alpha:]]+$                  Letters in the current locale
^[[:digit:]]+$                  Digits
^[[:alnum:]_]+$                 Letters, digits, or underscore
^[^0-9]+$                       One or more characters that are not digits
^https?://                      Starts with http:// or https://

GROUPS AND ALTERNATION
(...)   Groups parts of a pattern
|       Means OR inside a group: (cat|dog)
[^...]  A negated character class: anything except listed characters
\      Escapes a special character when needed, e.g. a literal dot: \.

BASH-SPECIFIC NOTES
- [[ text =~ pattern ]] uses extended regular expressions (ERE).
- Use [0-9], not \d. Bash ERE does not provide Perl-style \d.
- Lookahead and lookbehind are not supported by Bash's ERE engine.
- BASH_REMATCH[0] contains the full match; later indexes contain captured groups.
LESSON
  fi
  printf '\n'
  regex_learning_pause
}

regex_learning_playground() {
  local pattern sample status i
  while true; do
    banner "REGEX PRACTICE TESTER"
    printf '%s\n' "Enter a Bash ERE pattern and sample text."
    printf '%s\n' "Examples: ^[0-9]+$   or   ^(cat|dog)$"
    ask "Pattern (0 to return): " pattern
    [[ "$pattern" == "0" ]] && return 0
    ask "Sample text: " sample
    if [[ "$sample" =~ $pattern ]]; then
      ok "Match found."
      printf 'Full match: %s\n' "${BASH_REMATCH[0]}"
      for ((i=1; i<${#BASH_REMATCH[@]}; i++)); do
        printf 'Group %d: %s\n' "$i" "${BASH_REMATCH[$i]}"
      done
    else
      status=$?
      if (( status == 2 )); then
        err "The pattern is not a valid Bash extended regular expression."
      else
        warn "No match. Try changing the pattern or sample text."
      fi
    fi
    printf '\n'
    ask "Test another pattern? [Y/n]: " sample
    [[ "$sample" =~ ^[Nn]$ ]] && return 0
  done
}

regex_basic_menu() {
  local choice
  while true; do
    banner "BASIC REGEX LEARNING"
    printf '%s\n' \
      " 1) Read the basic regex lesson" \
      " 2) Practice with the regex tester" \
      " 0) Back"
    ask_choice "Choose: " choice "1 2 0" || return 0
    case "$choice" in
      1) regex_learning_examples BASIC ;;
      2) regex_learning_playground ;;
      0) return 0 ;;
    esac
  done
}

regex_advanced_menu() {
  local choice
  while true; do
    banner "ADVANCED REGEX LEARNING"
    printf '%s\n' \
      " 1) Read the advanced regex lesson" \
      " 2) Practice and inspect capture groups" \
      " 0) Back"
    ask_choice "Choose: " choice "1 2 0" || return 0
    case "$choice" in
      1) regex_learning_examples ADVANCED ;;
      2) regex_learning_playground ;;
      0) return 0 ;;
    esac
  done
}

regex_learning_menu() {
  local choice
  while true; do
    banner "LEARN REGEX"
    printf '%s\n' \
      " 1) Basic Regex" \
      " 2) Advanced Regex" \
      " 0) Back"
    ask_choice "Choose: " choice "1 2 0" || return 0
    case "$choice" in
      1) regex_basic_menu ;;
      2) regex_advanced_menu ;;
      0) return 0 ;;
    esac
  done
}
