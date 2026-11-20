# Termux Cyber Downloader & Android Toolkit

**Version:** 2.0.1 modular upgrade

A modular Termux downloader with video, subtitles, video-only mode, playlists, documents, audio, Telegram, queue, APK downloads, movie search, image tools, and a 4G settings shortcut. Supports Android Share → Termux and the DL launcher command.

## Features

- Modular Bash layout with shared configuration, colors, and helper functions.
- Video resolution selection, turbo downloads, timestamp trimming, English subtitles, and video-only downloads with selectable resolution.
- Playlist mode asks for a folder name and saves each playlist under its own folder in Movies.
- Playlist-aware filenames with playlist index numbers.
- Telegram downloads are saved in Movies/Telegram, with selectable 1, 2, 4, or 8 transfer threads.
- Telegram retries use tdl's --continue and --skip-same options to restore task progress and skip completed files.
- Direct document and archive downloads resume into a stable URL-derived filename when the server supports HTTP Range requests.
- Optional FFmpeg conversion after Telegram download creates a separate copy and retains the original.
- Sequential queue with failed or cancelled URLs retained for retry.
- Direct APK URL downloads plus APKPure/F-Droid options through apkeep. The local APK scanner and general Android control panel are not included.
- Direct document and archive downloads, automatically routed from Android Share or clipboard to Documents or Documents/APKs.
- One-tap shortcut to Android Radio Information for manual LTE-only / 4G selection.
- Image downloads from direct URLs and supported social/gallery pages through gallery-dl.
- Video thumbnail downloads.
- Image processing: square, widescreen, vertical and portrait crops; blurred fit; conversion/compression; metadata stripping; custom dimensions; Expo assets; Web/PWA assets; image-to-PDF.

## Install / update in Termux

```bash
pkg update && pkg upgrade -y
pkg install git python ffmpeg termux-api nano curl -y
pip install -U yt-dlp gallery-dl pillow
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

## Usage

- Type `DL` or `dl` to open the interactive main menu.
- Type `help` to open the help page.
- Share a supported URL from another app to Termux.
- Telegram `t.me` links auto-start the Telegram flow and save under `Movies/Telegram`.
- Supported document/file links auto-download to Documents or Documents/APKs.

### Video, subtitles, and playlists

Choose Best, 2160p, 1440p, 1080p, 720p, 480p, or 360p. Turbo mode uses eight parallel fragments when supported. Trim mode asks for start and end timestamps.

The Video Extras menu offers English manual/automatic subtitle downloads with embedding where supported, plus video-only downloads without an audio stream. Video-only mode now has its own Best/2160p/1440p/1080p/720p/480p/360p selector.

For playlists, enter a folder name before choosing the resolution. The playlist is saved in `~/storage/movies/<folder name>` with numbered filenames. Reuse the same folder name when retrying an interrupted playlist; yt-dlp's continue option and download archive help avoid restarting completed items.

### Documents and Android network settings

PDF, Office, ZIP/RAR/7z, EPUB, TXT, CSV, APK, and XAPK links shared to the launcher are routed to Documents or Documents/APKs. Downloads use a stable filename derived from the URL, allowing curl to continue a partial file when the server supports HTTP Range requests. Menu option 12 accepts a file URL manually.

Menu option 13 opens Android Radio Information. Selecting LTE only can lock a compatible device to 4G, but may affect voice calls; restore Auto or LTE/WCDMA when needed. The broader Android control panel and local APK scanner have been removed.

### Queue

Add links from the menu, edit the queue in nano, and run it sequentially. Failed or cancelled URLs remain in `data/download_queue.txt`.

### Telegram

Requires an authenticated `tdl` installation. Telegram media is saved in `~/storage/movies/Telegram`. Choose 1, 2, 4, or 8 transfer threads. The downloader uses `--continue --skip-same` to restore tdl's saved task progress and skip files already completed. Important: byte-level continuation of a partially downloaded single file is not available in every released tdl build. The upstream implementation is tracked in [tdl PR #1388](https://github.com/iyear/tdl/pull/1388); until a build containing that change is installed, a partial file may be discarded and restarted. After a successful download, choose whether to keep the original or create a 1080p, 720p, 480p, or 360p FFmpeg copy; the original is not overwritten.

### Images and media

The Image & Media Tools menu supports direct image URLs and gallery/social URLs through `gallery-dl`, video thumbnails through yt-dlp, and image processing through FFmpeg. Pillow is used for combining images into a PDF.

### APK downloads

Direct URLs are saved under Documents/APKs. The apkeep sources require apkeep to be installed. Verify APK provenance before installing. The old local APK scanner is removed.

### Movie / series search

Enter a title and choose Google, JustWatch, or IMDb to find legitimate availability. Streaming services may use DRM or other protections and may not provide downloadable media.

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
  documents.sh
  image.sh
  telegram.sh
  queue.sh
  apk.sh
  movie.sh
legacy/
  termux-url-opener  # retained as an inactive backup, not linked from the main menu
data/
  download_queue.txt
  download_history.txt
```

## Notes and limitations

- yt-dlp `-N 8` controls concurrent fragment downloads, not a guaranteed eightfold speedup. Some sites do not support fragment concurrency.
- Telegram's selected `tdl -t` value controls Telegram transfer workers. More threads do not guarantee higher speed; connection quality and Telegram/API behavior also matter.
- Telegram byte-level partial-file resume depends on the installed tdl build. `--continue` and `--skip-same` do not guarantee resuming the bytes of an unfinished single file.
- HTTP file resume requires the server to support byte ranges and to return a compatible response.
- Social/gallery image downloads depend on the site's support in the installed gallery-dl version.
- The Android Radio Information activity may differ across device manufacturers and Android versions. LTE-only mode may disable voice calls.
- Movie search only helps locate legitimate availability; it does not download copyrighted movies from unauthorized sources.
- This is a Termux Bash toolkit. Only use network or device functions on systems you own or are authorized to manage.

## Dependencies

Core: Bash, yt-dlp, Python, curl. FFmpeg is required for video/image processing. Termux:API is optional for notifications and media scanning. Optional: gallery-dl (social/gallery image downloads), Pillow (image-to-PDF), tdl (Telegram), apkeep (APK sources), nano (queue editing). Android Radio Information shortcut requires the Android activity manager, normally available in Termux.
