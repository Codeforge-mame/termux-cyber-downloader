# Termux Cyber Downloader & Android Toolkit

**Version:** 2.0.1 modular upgrade

A Termux command-line downloader and Android toolkit with a Matrix green/cyan terminal theme. It supports Android Share → Termux and the DL launcher command.

## What's new in 2.0.1

- Modular Bash layout with shared configuration, colors, and helper functions.
- Resolution selection for standard, turbo, and timestamp-trim video downloads.
- Turbo mode uses yt-dlp -N 8 where supported by the extractor.
- Telegram public links are auto-routed and downloaded using tdl -t 8.
- Optional FFmpeg conversion after Telegram download creates a separate copy and retains the original.
- Sequential queue with failed URLs retained for retry.
- Direct APK URL downloads plus APKPure/F-Droid options through apkeep.
- Movie title search helper points to legitimate streaming, rental, library, and official sources. It does not retrieve pirated copies.
- Separate help script. Original launcher is backed up under legacy/ to preserve existing image/Expo and Android tools while they are migrated.

## Install / update in Termux

```bash
pkg update && pkg upgrade -y
pkg install git python ffmpeg termux-api nano curl -y
pip install -U yt-dlp
termux-setup-storage

git clone -b v2.0.1-modular-upgrade https://github.com/Codeforge-mame/termux-cyber-downloader.git ~/termux-cyber-downloader
# If already cloned:
cd ~/termux-cyber-downloader
git fetch origin
git checkout v2.0.1-modular-upgrade
git pull --ff-only origin v2.0.1-modular-upgrade

mkdir -p ~/bin
cp ~/termux-cyber-downloader/termux-url-opener ~/bin/termux-url-opener
cp ~/termux-cyber-downloader/help_script ~/bin/cyber-help
chmod +x ~/bin/termux-url-opener ~/bin/cyber-help
```

Add shortcuts to ~/.bashrc:

```bash
echo 'alias DL="$HOME/bin/termux-url-opener"' >> ~/.bashrc
echo 'alias dl="$HOME/bin/termux-url-opener"' >> ~/.bashrc
echo 'alias help="bash $HOME/termux-cyber-downloader/help_script"' >> ~/.bashrc
source ~/.bashrc
```

If the repository is installed in a different directory, update the help alias path. Android Share → Termux uses Termux's termux-url-opener integration; copy the launcher into the Termux bin directory as shown above.

## Usage

- Type DL or dl to open the menu.
- Type help to open the help page.
- Share a supported URL from another app to Termux.
- Telegram t.me links auto-start an 8-thread download, then offer optional conversion.

### Video modes

Choose Best, 2160p, 1440p, 1080p, 720p, 480p, or 360p. Turbo mode uses eight parallel fragments when supported. Trim mode asks for start and end timestamps and applies the selected format cap.

### Queue

Add links from the menu, edit the queue in nano, and run it sequentially. Failed links remain in data/download_queue.txt.

### Telegram

Requires an authenticated tdl installation. Login using the method supported by your installed tdl version. Conversion requires FFmpeg and writes a new file; the original is not overwritten.

### APK downloads

Direct URLs are saved under Documents/APKs. The apkeep sources require apkeep to be installed. Verify APK provenance before installing.

## Project layout

```text
termux-url-opener
help_script
lib/
  colors.sh
  config.sh
  common.sh
modules/
  main_menu.sh
  video.sh
  telegram.sh
  queue.sh
  apk.sh
  movie.sh
legacy/
  termux-url-opener
data/
  download_queue.txt
  download_history.txt
```

## Notes and limitations

- yt-dlp -N 8 controls concurrent fragment downloads, not a guaranteed eightfold speedup. Some sites do not support fragment concurrency.
- Telegram's tdl -t 8 controls Telegram transfer workers. Resolution conversion is a separate FFmpeg operation.
- The legacy script is preserved, not yet fully ported. Its image/Expo, document, and Android utilities remain available from the legacy launcher. Some legacy paths may depend on functions or tools from your prior local version.
- Movie search only helps locate legitimate availability; it does not download copyrighted movies from unauthorized sources.
- This is a Termux Bash toolkit, not a security-testing tool. Only use network or device functions on systems you own or are authorized to manage.

## Dependencies

Core: Bash, yt-dlp, Python, Termux:API (optional for notifications/media scan), FFmpeg (conversion/trim), curl.
Optional: tdl (Telegram), apkeep (APK sources), nano (queue editing).
