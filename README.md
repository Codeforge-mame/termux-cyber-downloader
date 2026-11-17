# Termux Cyber Downloader & Android Toolkit

An all-in-one Termux command-line downloader and zero-app Android control toolkit triggered via the Android **Share Menu** or the **`dl`** clipboard alias.

## Features
- **Video & Playlist Matrix (`yt-dlp`):** Supports Best Quality, 720p, 480p, 360p, embedded English subtitles, silent video-only streams, timestamp clip trimming, and parallel fragment acceleration (`-N 4` / `-N 8`).
- **Smart Playlist Folders:** Automatically creates subfolders inside `Movies/` for playlists while saving single videos directly to `Movies/`.
- **Telegram CLI Integration (`tdl`):** Auto-detects `t.me/` links and downloads 1GB+ files with 8 parallel threads and resume support (`--continue`).
- **Auto-Routing Document Downloader (`curl`):** Automatically routes `.pdf`, `.docx`, `.zip`, and `.apk` links to `Documents/` with custom filename prompts and extension preservation.
- **Batch Queue (`~/links.txt`):** Edit links in `nano` and choose batch resolution (`-N 8` Turbo).
- **Zero-App Android & Network Panel:** Quick launcher for `4G Only / Auto` (`RadioInfo`), smart App Info & Cache Manager, Battery Optimization, Data Saver, Storage Manager, Name-Filtered Local `.apk`/`.xapk` Scanner, and Online App Installer (`apkeep`).
- **Persistent Cyber UI:** Matrix-colored terminal menus with `Continue to Main Menu? (y/n)` loop, wake-lock protection, Android gallery refresh (`termux-media-scan`), and push notifications.

## Quick Installation

1. **Install Required Packages:**
   ```bash
   pkg update && pkg upgrade -y
   pkg install python ffmpeg termux-api nano tdl apkeep unzip curl -y
   pip install -U yt-dlp
   termux-setup-storage
   ```

2. **Install the Script & Aliases:**
   ```bash
   mkdir -p ~/bin
   cp termux-url-opener ~/bin/termux-url-opener
   chmod +x ~/bin/termux-url-opener

   echo 'alias dl="~/bin/termux-url-opener \"\$(termux-clipboard-get)\""' >> ~/.bashrc
   echo 'alias dlbatch="yt-dlp -4 -N 8 --download-archive ~/.yt-dlp-archive.txt -P ~/storage/movies -o \"%(playlist_title&{}/|)s%(title)s.%(ext)s\" -a ~/links.txt && > ~/links.txt"' >> ~/.bashrc
   echo 'alias 4g="am start -n com.android.phone/.settings.RadioInfo"' >> ~/.bashrc
   source ~/.bashrc
   ```

## Usage
- **From Any App:** Tap **Share -> Termux**.
- **From Clipboard:** Copy any link and run `dl` in Termux.
- **Quick 4G Lock:** Run `4g` in Termux to open `RadioInfo`.
