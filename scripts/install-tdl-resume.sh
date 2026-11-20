#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

TDL_REPO="https://github.com/Soupboy006/tdl.git"
TDL_COMMIT="de945f54fad2b385a785d436bbdc7b2973d7aa91"
MIN_GO="1.25.8"

fail() {
  printf '\n[ERR] %s\n' "$*" >&2
  exit 1
}

[ -n "${PREFIX:-}" ] || fail "This installer is intended for Termux. PREFIX is not set."
[ -d "$PREFIX/bin" ] || fail "Termux bin directory not found: $PREFIX/bin"

if ! command -v git >/dev/null 2>&1 || ! command -v go >/dev/null 2>&1; then
  command -v pkg >/dev/null 2>&1 || fail "Install git and golang with Termux pkg first."
  printf '[INFO] Installing build dependencies...\n'
  pkg install -y git golang
fi

command -v git >/dev/null 2>&1 || fail "git is still unavailable."
command -v go >/dev/null 2>&1 || fail "Go is still unavailable."

GO_VERSION="$(go env GOVERSION | sed 's/^go//')"
IFS=. read -r GO_MAJOR GO_MINOR GO_PATCH <<< "$GO_VERSION"
GO_PATCH="${GO_PATCH%%[^0-9]*}"
GO_MAJOR="${GO_MAJOR:-0}"
GO_MINOR="${GO_MINOR:-0}"
GO_PATCH="${GO_PATCH:-0}"

if (( GO_MAJOR < 1 || (GO_MAJOR == 1 && GO_MINOR < 25) || (GO_MAJOR == 1 && GO_MINOR == 25 && GO_PATCH < 8) )); then
  fail "tdl resume patch requires Go $MIN_GO or newer; found go$GO_VERSION. Update Termux golang with: pkg upgrade golang"
fi

BUILD_TMP="${TMPDIR:-$PREFIX/tmp}"
mkdir -p "$BUILD_TMP"
BUILD_ROOT="$(mktemp -d "$BUILD_TMP/tdl-resume-build.XXXXXX")"
cleanup() { rm -rf "$BUILD_ROOT"; }
trap cleanup EXIT INT TERM

printf '[INFO] Fetching tdl source at pinned commit %s...\n' "${TDL_COMMIT:0:7}"
git init -q "$BUILD_ROOT/src"
git -C "$BUILD_ROOT/src" remote add origin "$TDL_REPO"
git -C "$BUILD_ROOT/src" fetch --depth 1 origin "$TDL_COMMIT"
git -C "$BUILD_ROOT/src" checkout -q --detach FETCH_HEAD

cd "$BUILD_ROOT/src"
printf '[INFO] Building tdl with byte-level resume support. This may take several minutes...\n'
GOTOOLCHAIN=local GOMAXPROCS="${GOMAXPROCS:-2}" go build -trimpath -ldflags="-s -w" -o "$BUILD_ROOT/tdl" .

[ -s "$BUILD_ROOT/tdl" ] || fail "Build did not produce a tdl executable."
"$BUILD_ROOT/tdl" --help >/dev/null 2>&1 || fail "The newly built tdl executable failed its help check."

BACKUP="$PREFIX/bin/tdl.stable-backup"
if [ -x "$PREFIX/bin/tdl" ] && [ ! -e "$BACKUP" ]; then
  cp -p "$PREFIX/bin/tdl" "$BACKUP"
  printf '[INFO] Existing tdl backed up to %s\n' "$BACKUP"
fi

install -m 755 "$BUILD_ROOT/tdl" "$PREFIX/bin/tdl"

if ! "$PREFIX/bin/tdl" --help >/dev/null 2>&1; then
  if [ -x "$BACKUP" ]; then
    cp -p "$BACKUP" "$PREFIX/bin/tdl"
  fi
  fail "Installed tdl failed verification; restored the previous binary when available."
fi

MARKER_DIR="$PREFIX/share/termux-cyber-downloader"
mkdir -p "$MARKER_DIR"
printf '%s\n' "$TDL_COMMIT" > "$MARKER_DIR/tdl-resume-commit"

printf '\n[OK] Installed tdl with byte-level Telegram resume support.\n'
printf '[INFO] Source commit: %s\n' "$TDL_COMMIT"
printf '[INFO] Your existing tdl authentication data was not changed.\n'
printf '[INFO] Test by interrupting a large Telegram file with Ctrl+C, then retrying the same link.\n'
