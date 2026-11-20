# Termux Cyber Downloader & Android Toolkit

**Version:** 2.0.1 modular upgrade

A modular Termux downloader with video, playlist, audio, Telegram, queue, APK, movie-search, and image tools. Supports Android Share → Termux and the DL launcher command.

## Features

- Modular Bash layout with shared configuration, colors, and helper functions.
- Video resolution selection, turbo downloads, and timestamp trimming.
- Dedicated playlist mode with each playlist saved in its own subfolder under Movies.
- Playlist-aware filenames with playlist index numbers.
- Telegram public links auto-route; choose 1, 2, 4, or 8 transfer threads.
- Optional FFmpeg conversion after Telegram download creates a separate copy and retains the original.
- Sequential queue with failed or cancelled URLs retained for retry.
- Direct APK URL downloads plus APKPure/F-Droid options through apkeep.
- Movie title search for legitimate streaming, rental, library, and official sources.
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

- Type `DL` or `dl` to open the main menu.
- Type `help` to open the help page.
- Share a supported URL from another app to Termux.
- Telegram `t.me` links auto-start the Telegram flow.

### Video and playlists

Choose Best, 2160p, 1440p, 1080p, 720p, 480p, or 360p. Turbo mode uses eight parallel fragments when supported. Trim mode asks for start and end timestamps.

Use the dedicated Playlist option for playlist URLs. The downloader uses yt-dlp's playlist title and index output template, creating a separate folder for each playlist under `~/storage/movies`. The download archive prevents already-downloaded entries from being downloaded again.

### Queue

Add links from the menu, edit the queue in nano, and run it sequentially. Failed or cancelled URLs remain in `data/download_queue.txt`.

### Telegram

Requires an authenticated `tdl` installation. Choose 1, 2, 4, or 8 transfer threads. After a successful download, choose whether to keep the original or create a 1080p, 720p, 480p, or 360p FFmpeg copy; the original is not overwritten.

### Images and media

The Image & Media Tools menu supports direct image URLs and gallery/social URLs through `gallery-dl`, video thumbnails through yt-dlp, and image processing through FFmpeg. Pillow is used for combining images into a PDF.

### APK downloads

Direct URLs are saved under Documents/APKs. The apkeep sources require apkeep to be installed. Verify APK provenance before installing.

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
  image.sh
  telegram.sh
  queue.sh
  apk.sh
  movie.sh
legacy/
  termux-url-opener  # retained as a backup; not linked from the main menu
data/
  download_queue.txt
  download_history.txt
```

## Notes and limitations

- yt-dlp `-N 8` controls concurrent fragment downloads, not a guaranteed eightfold speedup. Some sites do not support fragment concurrency.
- Telegram's selected `tdl -t` value controls Telegram transfer workers. More threads do not guarantee higher speed; connection quality and Telegram/API behavior also matter.
- Social/gallery image downloads depend on the site's support in the installed gallery-dl version.
- Movie search only helps locate legitimate availability; it does not download copyrighted movies from unauthorized sources.
- This is a Termux Bash toolkit. Only use network or device functions on systems you own or are authorized to manage.

## Dependencies

Core: Bash, yt-dlp, Python, curl. FFmpeg is required for video/image processing. Termux:API is optional for notifications and media scanning. Optional: gallery-dl (social/gallery image downloads), Pillow (image-to-PDF), tdl (Telegram), apkeep (APK sources), nano (queue editing).
