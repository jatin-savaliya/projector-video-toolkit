# Projector Video Toolkit

Windows tools for anyone who plays videos from a USB drive on a budget projector.

Budget projectors usually play only a narrow set of formats (typically **H.264 video + AAC audio**), cannot switch audio tracks, and fail silently or show a black screen when a file doesn't fit. This toolkit does three things:

1. **Scans a whole folder** and tells you which videos the projector can play and which it can't.
2. **Converts only the videos that need it**, copying whatever is already fine, so nothing is re-encoded unnecessarily.
3. **Keeps a single audio track** in files that have many languages, because the projector always plays the first track and has no way to change it.

Everything runs locally on your PC using [ffmpeg](https://ffmpeg.org). No internet connection, no accounts, no installation.

> **Platform:** Windows 10 or later only. The scripts have not been tested on macOS or Linux, so nothing here claims to work there.

---

## The tools

| File | What it does | Use it when |
|------|--------------|-------------|
| `scan_folder_compatible.bat` | Scans a folder, renames each video to `_compatible` or `_not_compatible`, then lets you choose which incompatible files to convert. | You have a folder of videos for the projector. **Start here.** |
| `keep_one_audio.bat` | Lists the audio tracks in one file and writes a copy that contains only the track you choose. | A file has several audio languages and you want just one. |
| `make_compatible.bat` | The original single-file checker and converter. | You want to check or convert exactly one file. |

---

## Quick start

1. **Download this repository:** click the green **Code** button, then **Download ZIP**, and unzip it.
2. **Get ffmpeg:** download a Windows build from <https://ffmpeg.org/download.html>. From the zip, copy `ffmpeg.exe` and `ffprobe.exe` (they are in the `bin` folder) into the same folder as the `.bat` files. These are not included in this repository.
3. **Run a tool:** double-click `scan_folder_compatible.bat`.
4. **Paste the path of your video folder** and press Enter.
5. When the scan finishes, pick the files you want converted from the numbered list.

For a step-by-step walkthrough with explanations of every screen, read the [Beginner Guide](docs/BeginnerGuide.md).

---

## How a file is judged

A video is **compatible** when:

- the video codec is **H.264**, and
- **every** audio track is **AAC**.

Anything else is **not compatible**. The container (MP4, MKV, ...) is not checked. If your projector plays MKV files with H.264 and AAC inside, they are treated as compatible.

When a file is converted, only the parts that need it are re-encoded: H.264 video is copied as-is, and each audio track that is already AAC is copied as-is. Subtitles are always dropped.

---

## Safety notes

- **The scanner renames your files.** It adds `_compatible` or `_not_compatible` to the file name. Try it on a folder of copies first.
- Original files are never deleted by any of these tools.
- Converted files are written under a temporary name and renamed only when the conversion succeeds.

---

## Documentation

- **[Beginner Guide](docs/BeginnerGuide.md):** setup and use for non-technical users, with troubleshooting.
- **[Developer Guide](docs/DeveloperGuide.md):** how the scripts work, the exact ffmpeg commands, how to customise and test them.

---

## Known limitations

- Only codecs are checked. A file with H.264 + AAC can still fail on a projector if it is 4K, 10-bit, or uses an unusual profile or frame rate.
- Only the first video stream is kept. Subtitles are always removed.
- Only files directly inside the chosen folder are scanned, not subfolders.
- Tested with a PANSEBA budget projector. Other projectors may support different formats.

---

## License

MIT. See [LICENSE](LICENSE).

This repository does not include or redistribute ffmpeg. ffmpeg is a separate project with its own license.
