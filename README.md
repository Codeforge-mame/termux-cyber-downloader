<!-- Replace the banner path after the repository artwork is added. -->

# Termux Cyber Downloader

A modular, menu-driven downloader and media toolkit for **Termux on Android**. Download videos, audio, Telegram media, playlists, documents, APKs, and images, then process media and prepare image assets directly from your phone.

<p align="center">
  <a href="https://github.com/Codeforge-mame/termux-cyber-downloader">
    <img src="https://img.shields.io/badge/Platform-Termux-2E8B57?style=for-the-badge&logo=android&logoColor=white" alt="Termux">
  </a>
  <img src="https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/Video-yt--dlp-111111?style=for-the-badge" alt="yt-dlp">
  <img src="https://img.shields.io/badge/Media-FFmpeg-007808?style=for-the-badge&logo=ffmpeg&logoColor=white" alt="FFmpeg">
  <img src="https://img.shields.io/badge/Language-Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python">
</p>

## Features

- **Video downloads:** choose Best, 2160p, 1440p, 1080p, 720p, 480p, or 360p.
- **Turbo downloads:** use up to eight yt-dlp fragments when the source supports it.
- **Video extras:** download English subtitles or a video-only stream.
- **Trim videos:** download a selected time range.
- **Audio:** extract audio and save it as MP3.
- **Playlists:** save a playlist into a named folder with numbered filenames.
- **Telegram:** download public Telegram media with selectable 1, 2, 4, or 8 transfer threads using the standard `tdl` release.
- **Documents and archives:** download PDF, Office, ZIP, RAR, 7z, EPUB, TXT, CSV, APK, and XAPK files.
- **Sequential queue:** process queued links one by one and keep failed or cancelled links for retry.
- **APK downloads:** direct APK URLs and optional APKPure/F-Droid sources through `apkeep`.
- **Image and media tools:** download images and supported gallery posts, save video thumbnails, crop/resize/convert images, remove metadata, create Expo or Web/PWA assets, and combine images into a PDF.
- **Movie and series search:** find legitimate availability through Google, JustWatch, or IMDb.
- **Android shortcut:** open Android Radio Information for manual LTE/4G network selection.
- **Android sharing:** share supported links from another app to Termux.

## Requirements

Use the **Termux app from F-Droid or the official Termux GitHub releases**. Avoid mixing Termux with the outdated Play Store build.

### Required packages

Run these commands inside Termux:

```bash
pkg update && pkg upgrade -y
pkg install git python ffmpeg curl tdl -y
python -m pip install -U yt-dlp
termux-setup-storage
```

When Android asks for storage access, allow it. This lets the downloader save files in your shared Movies, Music, Pictures, and Documents folders.

### Optional packages

Install these only if you want their related features:

```bash
# Social/gallery image downloads
python -m pip install -U gallery-dl

# Image-to-PDF support
python -m pip install -U pillow

# Android notifications and media scanning
pkg install termux-api -y

# Editing the download queue
pkg install nano -y
```

The APKPure and F-Droid menu options require `apkeep`, which is an optional external tool and must be installed separately. Direct APK URL downloads do not require it.

## Installation

Clone the latest stable version from the `main` branch:

```bash
git clone -b main https://github.com/Codeforge-mame/termux-cyber-downloader.git ~/termux-cyber-downloader
cd ~/termux-cyber-downloader

mkdir -p ~/bin
cp termux-url-opener ~/bin/termux-url-opener
cp help_script ~/bin/cyber-help
chmod +x ~/bin/termux-url-opener ~/bin/cyber-help
```

Add convenient commands to your Termux shell:

```bash
echo 'alias DL="bash $HOME/bin/termux-url-opener"' >> ~/.bashrc
echo 'alias dl="bash $HOME/bin/termux-url-opener"' >> ~/.bashrc
echo 'alias cyber-help="bash $HOME/bin/cyber-help"' >> ~/.bashrc
source ~/.bashrc
```

## How to use

### Open the downloader

```bash
DL
```

You can also run it without setting up aliases:

```bash
bash ~/bin/termux-url-opener
```

The interactive menu guides you through each operation. Enter the menu number, provide the requested URL or options, and choose where applicable.

### Open the help guide

```bash
cyber-help
```

Or:

```bash
bash ~/bin/cyber-help
```

### Share a link from Android

1. Open the app containing the link.
2. Tap **Share**.
3. Choose **Termux**.
4. The launcher detects supported Telegram and document links automatically. Other links open the main menu with the shared URL.

### Where files are saved

Downloads are organized in your Termux shared storage, usually under:

- Videos: `~/storage/movies`
- Telegram: `~/storage/movies/Telegram`
- Music: `~/storage/music`
- Images: `~/storage/pictures`
- Documents: `~/storage/shared/Documents`
- APKs: `~/storage/shared/Documents/APKs`

The exact folders are configured by the toolkit and may be adjusted in its configuration file.

## Update

If you already installed the repository, update it with:

```bash
cd ~/termux-cyber-downloader
git switch main
git pull --ff-only origin main

cp termux-url-opener ~/bin/termux-url-opener
cp help_script ~/bin/cyber-help
chmod +x ~/bin/termux-url-opener ~/bin/cyber-help
```

Your download history and queue are stored in the repository's `data/` directory. Back up any local changes to those files before switching branches or replacing local files.

## Important behavior and limitations

- **Telegram resume:** the standard `tdl` release is used. The script passes `--continue --skip-same`, but an interrupted temporary download may be removed by `tdl`; retrying may start that file again. Byte-level Telegram resume is not included.
- **Document resume:** continuing a partial download depends on the remote server supporting HTTP Range requests.
- **Download speed:** turbo mode and additional Telegram threads do not guarantee faster downloads. Actual speed depends on the source, network, and server limits.
- **Image downloads:** social/gallery downloads depend on the site's support in the installed `gallery-dl` version.
- **Network shortcut:** LTE-only mode may affect voice calls. Restore Auto or LTE/WCDMA if needed.
- **APK safety:** verify the publisher and APK signature before installing packages, especially from third-party sources.
- **Copyright and authorization:** only download content you own, have permission to access, or are otherwise legally allowed to download.

## Project structure

```text
termux-cyber-downloader/
├── termux-url-opener
├── help_script
├── lib/
│   ├── colors.sh
│   ├── config.sh
│   └── common.sh
├── modules/
│   ├── main_menu.sh
│   ├── video.sh
│   ├── documents.sh
│   ├── image.sh
│   ├── telegram.sh
│   ├── queue.sh
│   ├── apk.sh
│   └── movie.sh
├── legacy/       # inactive backup
└── data/         # queue and download history
```

## Contributing

Issues, bug reports, and practical improvements are welcome. When reporting a problem, include the Termux version, Android version, the menu option used, and the relevant error output. Remove private URLs or personal information before posting logs.

---

**Maintained by [Codeforge-mame](https://github.com/Codeforge-mame).**
