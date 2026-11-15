# Projector Video Toolkit

Windows batch tools for people who play videos from a USB drive on a budget
projector. They scan a folder, work out which videos the projector can't play,
transcode only those, and keep a single audio track for projectors that can't
switch tracks.

Everything runs locally on your PC using ffmpeg. No network or install needed.

## What is in this repo

| File | What it does |
|------|--------------|
| `scan_folder_compatible.bat` | Scans a folder, renames each video to `_compatible` or `_not_compatible`, then lets you pick which incompatible files to transcode. |
| `make_compatible.bat` | Checks one file and transcodes it to H.264 + AAC (MP4) only if needed. |
| `keep_one_audio.bat` | Lists the audio tracks of one file and writes a copy with only the track you choose. |

## Requirements

- Windows 10 or later
- `ffmpeg.exe` and `ffprobe.exe`, downloaded separately from https://ffmpeg.org/download.html
  (they are not included in this repo)

Put `ffmpeg.exe` and `ffprobe.exe` in the same folder as the `.bat` files,
or add their folder to your PATH.

## How to use

### 1. Scan a whole folder
1. Double-click `scan_folder_compatible.bat`.
2. Paste the folder path. Only files directly in that folder are read, not subfolders.
3. Files already ending in `_compatible` or `_not_compatible` are skipped.
4. Each remaining video is renamed `name_compatible.ext` or `name_not_compatible.ext`.
5. A numbered list of `_not_compatible` files appears. Type numbers like `1,3,5`,
   `all`, or press Enter to skip.
6. Transcoding writes `name_compatible.mp4`. The original stays as `name_not_compatible.ext`.

### 2. Keep only one audio track
1. Double-click `keep_one_audio.bat`.
2. Paste the path of the video file.
3. Pick the audio track to keep. A new file `name_1audio.ext` is written with only
   that track. The original is not touched.

## Compatibility rule

A file counts as compatible when the video codec is **H.264** and **every audio
track is AAC**. The container (for example MKV) is not checked.
Incompatible files are transcoded per track: streams that are already fine are
copied, and only the incompatible ones are re-encoded.

## Notes

- Subtitles are always dropped.
- Video is not re-encoded when it is already H.264, and audio tracks are not
  re-encoded when they are already AAC.
- Transcoding writes to a temporary name (`..._underTranscoding_not_compatible.mp4`)
  and renames it only on success. If a run is interrupted, delete the leftover file.
- Tested with a PANSEBA budget projector. Other projectors may need different codecs.

## License

MIT
