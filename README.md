# Termux Cyber Downloader & Android Toolkit

An all-in-one Termux command-line media downloader and zero-app Android control toolkit triggered via the Android **Share Menu** or the **`dl`** clipboard alias.

## Features
- **Video & Playlist Matrix (`yt-dlp`):** Supports Best Quality, 720p, 480p, 360p, embedded English subtitles, silent video-only streams, timestamp clip trimming, and parallel fragment acceleration (`-N 2` to `-N 8`).
- **429 Rate-Limit Auto-Recovery:** Automatically detects YouTube `HTTP Error 429` blocks, pauses with a push notification alert, and resumes seamlessly after toggling Airplane Mode.
- **Smart Playlist & Separate Archives:** Automatically organizes playlists into dedicated subfolders inside `Movies/` and separates audio vs. video history archives so downloading an MP3 never blocks downloading the video later.
- **Telegram CLI Integration (`tdl`):** Auto-detects `t.me/` links and downloads 1GB+ files with 8 parallel threads and resume support (`--continue`).
- **Auto-Routing Document Downloader (`curl`):** Automatically routes `.pdf`, `.docx`, `.zip`, and `.apk`/`.xapk` links to `Documents/` with custom filename prompts and extension preservation.
- **Batch Queue (`~/links.txt`):** Edit links in `nano` and choose batch resolution (`-N 8` Turbo).
- **Zero-App Android & Network Panel:** Quick launcher for `4G Only / Auto` (`RadioInfo`), smart App Info & Cache Manager, Battery Optimization, Data Saver, Storage Manager, Name-Filtered Local `.apk`/`.xapk` Scanner, and Online App Installer (`apkeep`).

## Requirements
- **Android Device** with **Termux** (official [GitHub](https://github.com) or F-Droid release recommended) and **Termux:API** companion app.
- **Required Termux Packages:** `git`, `python`, `ffmpeg`, `termux-api`, `nano`, `tdl`, `apkeep`, `unzip`, `curl`, and `yt-dlp`.

## Quick Installation

1. **Update Termux & Install Required Packages:**
   ```bash
   pkg update && pkg upgrade -y
   pkg install git python ffmpeg termux-api nano tdl apkeep unzip curl -y
   pip install -U yt-dlp
   termux-setup-storage
   ```

2. **Clone This Repository & Install the Script:**
   ```bash
   git clone https://github.com\$(gh api user -q .login 2>/dev/null || echo "YOUR_USERNAME")/termux-cyber-downloader.git ~/termux-cyber-downloader
   mkdir -p ~/bin
   cp ~/termux-cyber-downloader/termux-url-opener ~/bin/termux-url-opener
   chmod +x ~/bin/termux-url-opener
   ```
   *(Replace `YOUR_USERNAME` with your GitHub username if `gh` is not installed).*

3. **Set Up Terminal Shortcuts (`dl`, `dlbatch`, `4g`):**
   ```bash
   echo 'alias dl="~/bin/termux-url-opener \"\$(termux-clipboard-get)\""' >> ~/.bashrc
   echo 'alias dlbatch="yt-dlp -4 -N 3 --sleep-interval 5 --max-sleep-interval 12 --download-archive ~/.yt-dlp-archive.txt -P ~/storage/movies -o \"%(playlist_title&{}/|)s%(title)s.%(ext)s\" -a ~/links.txt && > ~/links.txt"' >> ~/.bashrc
   echo 'alias 4g="am start -n com.android.phone/.settings.RadioInfo"' >> ~/.bashrc
   source ~/.bashrc
   ```

4. **Log Into Telegram CLI (`tdl`) for 1GB+ Telegram Links:**
   ```bash
   tdl login --code
   ```

## Usage
- **From Any App:** Tap **Share -> Termux**.
- **From Clipboard:** Copy any link and type `dl` in Termux.
- **Quick 4G Lock:** Type `4g` in Termux to open `RadioInfo`.
