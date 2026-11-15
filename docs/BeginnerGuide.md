# Beginner Guide

This guide assumes **no technical knowledge**. If you can copy files, paste text and double-click, you can use these tools.

## Contents

1. [What these tools are for](#1-what-these-tools-are-for)
2. [A few words explained](#2-a-few-words-explained)
3. [What you need](#3-what-you-need)
4. [Step 1: Download the toolkit](#4-step-1-download-the-toolkit)
5. [Step 2: Download ffmpeg](#5-step-2-download-ffmpeg)
6. [Step 3: Put the files together](#6-step-3-put-the-files-together)
7. [Step 4: Do a safe test run](#7-step-4-do-a-safe-test-run)
8. [Tool 1: Scan a folder (scan_folder_compatible.bat)](#8-tool-1-scan-a-folder)
9. [Tool 2: Keep one audio track (keep_one_audio.bat)](#9-tool-2-keep-one-audio-track)
10. [Tool 3: Check one file (make_compatible.bat)](#10-tool-3-check-one-file)
11. [Copying the videos to your USB drive](#11-copying-the-videos-to-your-usb-drive)
12. [Troubleshooting](#12-troubleshooting)
13. [Frequently asked questions](#13-frequently-asked-questions)
14. [Safety tips](#14-safety-tips)

---

## 1. What these tools are for

You copy a movie to a USB drive, plug it into your projector, and one of these happens:

- the screen stays black,
- you hear nothing, or
- the movie plays in the wrong language, and the projector has no menu to change it.

Budget projectors only understand a small set of video formats. These tools find the videos that won't play, fix only those, and let you choose one audio language when a file has many.

## 2. A few words explained

You will see these words in the tool. You don't need to remember them.

| Word | Plain meaning |
|------|---------------|
| **Codec** | The "language" a video or sound is stored in. The projector understands some codecs and not others. |
| **H.264** | A very common video codec. Your projector understands it. |
| **AAC** | A very common audio codec. Your projector understands it. |
| **Transcode / convert** | Changing a file from one codec to another so the projector can play it. This can take a while. |
| **Audio track** | One sound version of the movie, for example Hindi, English or Gujarati. Some files contain many. |
| **Copy (no re-encoding)** | Moving the picture or sound into the new file untouched. Very fast and loses no quality. |

## 3. What you need

- A Windows 10 or Windows 11 computer
- An internet connection, for the one-time downloads
- Enough free disk space for converted copies (a converted movie can be as large as the original)
- Your videos in a folder on the computer

No installation is needed. Nothing is changed on your computer other than your videos.

## 4. Step 1: Download the toolkit

1. Open the toolkit's GitHub page in your browser.
2. Click the green **Code** button.
3. Click **Download ZIP**.
4. When the download finishes, open your **Downloads** folder.
5. Right-click the ZIP file and choose **Extract All...**, then click **Extract**.
6. A normal folder opens. It contains the `.bat` files.

## 5. Step 2: Download ffmpeg

ffmpeg is a free program that does the actual checking and converting. It is not included in this toolkit, so you download it once.

1. Go to <https://ffmpeg.org/download.html>.
2. Under **Windows**, click one of the Windows builds. A common choice is the "release essentials" build from gyan.dev. The websites that host builds can change, so follow the link on the ffmpeg page.
3. Download the `.zip` file and extract it the same way as before.
4. Open the extracted folder, then open the folder named **bin**.
5. Inside `bin` you will see `ffmpeg.exe`, `ffprobe.exe` and `ffplay.exe`. You need the first two.

## 6. Step 3: Put the files together

1. Open the toolkit folder (the one with the `.bat` files).
2. Copy `ffmpeg.exe` and `ffprobe.exe` from the `bin` folder.
3. Paste them into the toolkit folder, next to the `.bat` files.

The folder should now look like this:

```
projector-video-toolkit/
  scan_folder_compatible.bat
  keep_one_audio.bat
  make_compatible.bat
  ffmpeg.exe
  ffprobe.exe
  README.md
  ...
```

## 7. Step 4: Do a safe test run

The scanner **renames your files**. Before using it on your whole collection, try it on copies.

1. Create a new folder, for example `C:\Test`.
2. Copy **two or three** videos into it. Copies, not originals.
3. Use the tools on `C:\Test` first.

When you are comfortable with how it behaves, use it on your real folder.

> **If Windows shows a warning when you run a `.bat` file:** this is normal for files downloaded from the internet. Windows may say "Windows protected your PC" or ask "Do you want to open this file?". The scripts are plain text, so you can right-click one, choose **Edit** and read exactly what it does before running it. If you trust it, click **More info**, then **Run anyway** (or **Open**).

---

## 8. Tool 1: Scan a folder

`scan_folder_compatible.bat` is the main tool. It checks every video in a folder, labels each one, and offers to convert the ones that need it.

### How to copy a folder's path

The tool asks for the folder's "path", which is its address on your computer.

1. Open the folder in File Explorer.
2. Click once in the address bar at the top, so the address turns into plain text.
3. Press **Ctrl + C** to copy it.

### Running the scan

1. Double-click `scan_folder_compatible.bat`. A black window opens.
2. It asks: `Paste the full path of the video FOLDER (press Enter to exit)`.
3. Paste the path (right-click in the window, or press **Ctrl + V**) and press **Enter**.

The tool then checks each video. You will see lines like these:

```
[1/4] Movie One.mkv ... COMPATIBLE  (video: h264 | audio: aac)
[2/4] Movie Two.mp4 ... NOT COMPATIBLE  (video: hevc | audio: aac)
[3/4] Movie Three.avi ... NOT COMPATIBLE  (video: h264 | audio: ac3+aac)
```

- **COMPATIBLE** (green): the projector should play it. The file is renamed to `Movie One_compatible.mkv`.
- **NOT COMPATIBLE** (red): the projector probably won't play it. The file is renamed to `Movie Two_not_compatible.mp4`.
- **UNREADABLE** (yellow): the tool couldn't read the file at all. It is left untouched.

Nothing has been converted yet. Only the names changed.

### The summary

When the scan finishes you see a summary:

```
---------------- SUMMARY ----------------
Video files in folder        : 4
Skipped (already tagged)     : 0
Renamed _compatible          : 1
Renamed _not_compatible      : 2
-----------------------------------------
```

"Skipped (already tagged)" counts files whose names already end in `_compatible` or `_not_compatible`. They are not checked again, which makes repeated scans of a big folder fast.

### Choosing what to convert

Next you see a numbered list of files that still need converting:

```
Files waiting for transcoding:
    1. Movie Two_not_compatible.mp4  (1450.2 MB)
    2. Movie Three_not_compatible.avi  (700.8 MB)
Enter numbers (e.g. 1,3,5), 'all', or press Enter to skip
```

Type one of these and press **Enter**:

| You type | What happens |
|----------|--------------|
| `1` | Converts file number 1 only |
| `1,2` | Converts files 1 and 2, one after the other |
| `all` | Converts every file in the list |
| (just press Enter) | Skips converting for now |

Converting can take a long time, from a few seconds to well over an hour per movie, depending on what needs changing. You will see ffmpeg's progress text scrolling. **Leave the window open.**

### What converting creates

For `Movie Two_not_compatible.mp4`, the tool produces:

- `Movie Two_compatible.mp4`: the new file, ready for the projector.
- `Movie Two_not_compatible.mp4`: your original, kept untouched.

While a conversion is running, the new file has a temporary name ending in `_underTranscoding_not_compatible.mp4`. It is renamed to `_compatible.mp4` only when the conversion finishes successfully, so a half-finished file is never mistaken for a good one.

### After converting

The list appears again with whatever is left. Press **Enter** to finish. The tool asks `Scan another folder? (y/N)`. Type `y` to do another folder, or press Enter to close.

### Running it again later

You can run the scanner on the same folder whenever you add new videos. Already-labelled files are skipped. Files labelled `_not_compatible` in an earlier session, which have not yet been converted, appear in the list again so you can convert them whenever you like.

### If a conversion was interrupted

If you closed the window or the computer shut down during a conversion, a leftover file ending in `_underTranscoding_not_compatible.mp4` remains. The next scan lists these and asks `Delete these incomplete files? (y/N)`. Type `y` to remove them. Your original files are not affected.

---

## 9. Tool 2: Keep one audio track

Use `keep_one_audio.bat` when a video has several audio languages and you want only one. The projector plays the first audio track and cannot switch, so this removes the risk of getting the wrong language.

### Steps

1. Double-click `keep_one_audio.bat`.
2. It asks: `Paste the full path of the video FILE (press Enter to exit)`.
3. To get a file's path: hold **Shift**, right-click the file, and choose **Copy as path** (on Windows 11, right-click and choose **Copy as path**). Paste it into the window and press **Enter**. Quote marks around the path are fine.
4. The tool lists the audio tracks it found:

```
Audio tracks in: Movie.mkv
   1. hin  (aac, 5.1)
   2. eng - Director's Commentary  (ac3, stereo)
   3. guj  (aac, stereo)
Enter the number of the track to KEEP (press Enter to cancel)
```

5. Type the number of the track you want (for example `3`) and press **Enter**.

### What you get

A new file called `Movie_1audio.mkv` containing the video and **only** the track you chose. Your original `Movie.mkv` is not touched.

- It takes seconds, because nothing is re-encoded.
- Subtitles are removed.
- The new file keeps the same type as the original (an MKV stays an MKV, an MP4 stays an MP4).

### Good to know

- If a file has only one audio track, the tool says so and does nothing.
- If `Movie_1audio.mkv` already exists, the tool will not overwrite it.
- Track names such as `hin`, `eng` and `guj` come from labels stored in the file. If a file has no labels, they show as `unknown`, and you may need to test each track in a video player to find the right language.
- After this tool, you can run the folder scanner on the new file if you also want to check it for compatibility.

---

## 10. Tool 3: Check one file

`make_compatible.bat` is the original single-file tool. Use it if you only want to check or convert one specific video.

1. Double-click `make_compatible.bat`.
2. Paste the full path of the video file and press **Enter**.
3. It shows the video and audio codec it found.
   - If both are fine, it says `Already compatible. No action needed.`
   - Otherwise it converts the file and saves `name_compatible.mp4` next to the original.

This tool does not rename anything and handles only the first audio track. For folders, or files with several audio tracks, use Tool 1.

---

## 11. Copying the videos to your USB drive

1. Plug in the USB drive.
2. Copy the `_compatible` files to it. The `_not_compatible` originals are not needed on the drive.
3. Eject the drive from Windows before unplugging it (right-click the drive and choose **Eject**).
4. Plug it into the projector.

If you like, you can rename files before copying them to remove the `_compatible` ending. It makes no difference to the projector.

---

## 12. Troubleshooting

### "ERROR: ffmpeg.exe / ffprobe.exe not found."
The tool can't find ffmpeg. Make sure `ffmpeg.exe` and `ffprobe.exe` are in the **same folder** as the `.bat` file you are running, as in [Step 3](#6-step-3-put-the-files-together). If you moved a `.bat` file to another folder, move the two `.exe` files there too.

### The window opens and closes immediately
Run it from the folder rather than from inside the ZIP. Extract the ZIP first, then double-click the `.bat` file in the extracted folder.

### "Folder not found." or "File not found."
- Paste the full path, for example `D:\Movies`.
- Make sure you copied the whole path with nothing missing.
- Quote marks around the path are fine.

### A file shows UNREADABLE
The file may be damaged, unfinished (for example, a partial download), or not a real video even though its name ends in `.mp4`. Try opening it in a video player.

### "target name already exists, not renamed"
A file with the new name is already in the folder, for example you have both `Movie.mp4` and `Movie_compatible.mp4`. The tool will not overwrite it. Rename or move one of them and scan again.

### "rename failed"
Another program is probably using the file (a video player, a download, a backup program). Close it and run the scan again.

### "TRANSCODE FAILED"
Read the red error text printed above it. Common causes:
- **Not enough disk space.** Free some up and try again.
- **A damaged source file.** Try a different copy.
- **The file is open elsewhere.** Close other programs.

The failed temporary file is removed automatically, and your original is untouched.

### The file is labelled COMPATIBLE but still doesn't play on the projector
The tools only check the codecs. Some projectors also fail on 4K video, 10-bit colour, an unusual frame rate or a very high bitrate. If this happens, tell the project's maintainer which file it was, or try converting the file anyway using `make_compatible.bat` after removing `_compatible` from its name.

### Conversion is very slow
Converting video is demanding. A long movie can take a long time on an older laptop. Files where only the audio needs changing are much faster, because the video is copied.

### I labelled files by mistake and want to start over
Rename the files by hand to remove `_compatible` or `_not_compatible` from the end of their names. The scanner will check them again next time.

---

## 13. Frequently asked questions

**Will this damage my original videos?**
No. Originals are never deleted. The scanner only adds `_compatible` or `_not_compatible` to the name, and conversions create new files.

**Does it need internet?**
Only for the one-time downloads. The tools work offline.

**Does it check subfolders?**
No. Only files directly inside the folder you give it.

**Which video formats does it scan?**
`.mp4`, `.mkv`, `.avi`, `.mov`, `.wmv`, `.flv`, `.webm`, `.m4v`, `.ts`, `.m2ts`, `.mts`, `.mpg`, `.mpeg`, `.3gp`, `.vob` and `.ogv`.

**Is the picture quality reduced when converting?**
Only when the video itself needs converting; it is re-encoded at high quality, but any re-encode costs a little. If only the audio needs changing, the picture is copied untouched. Audio that is converted is saved as AAC at a good quality setting.

**Why are subtitles removed?**
Many budget projectors can't use them, and embedded subtitles can cause problems. The tools always leave them out.

**Does it work on Mac or Linux?**
It has not been tested on them, so it is documented for Windows only.

**Can I use it on files that are on my USB drive directly?**
Yes, but it is faster and safer to work on the computer's own drive and copy the results across afterwards.

---

## 14. Safety tips

- Try new tools on **copies** first.
- Keep your original `_not_compatible` files until you have played the converted ones on the projector and are happy with them.
- Don't close the window while a conversion is running.
- Don't unplug a USB drive while files are being converted or copied.
- Keep the downloaded `ffmpeg.exe` and `ffprobe.exe` from an official or well-known source.
