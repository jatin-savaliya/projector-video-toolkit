# Developer Guide

Internals, exact commands, customisation and testing for the Projector Video Toolkit. For plain usage instructions see the [Beginner Guide](BeginnerGuide.md).

## Contents

1. [Scope and platform](#1-scope-and-platform)
2. [Repository layout](#2-repository-layout)
3. [Architecture: batch launcher + embedded PowerShell](#3-architecture-batch-launcher--embedded-powershell)
4. [scan_folder_compatible.bat](#4-scan_folder_compatiblebat)
5. [keep_one_audio.bat](#5-keep_one_audiobat)
6. [make_compatible.bat](#6-make_compatiblebat)
7. [ffprobe and ffmpeg commands reference](#7-ffprobe-and-ffmpeg-commands-reference)
8. [Naming conventions and state](#8-naming-conventions-and-state)
9. [Customisation recipes](#9-customisation-recipes)
10. [Testing](#10-testing)
11. [Editing rules and gotchas](#11-editing-rules-and-gotchas)
12. [Known limitations](#12-known-limitations)
13. [Contributing](#13-contributing)

---

## 1. Scope and platform

- **Target:** Windows 10 / 11, using the Windows PowerShell 5.1 that ships with the OS. No other runtime is needed.
- **Dependencies:** `ffmpeg.exe` and `ffprobe.exe`, resolved from the script's own folder first, then from `PATH`. They are not part of this repository (`.gitignore` excludes `*.exe`).
- **Not verified:** macOS and Linux. The ffprobe/ffmpeg commands are cross-platform, but the scripts themselves have not been run or tested outside Windows, so no support is claimed.
- **Design goal:** target a budget projector that plays H.264 + AAC, cannot select audio tracks, and should receive the minimum necessary re-encoding.

## 2. Repository layout

```
.
|-- scan_folder_compatible.bat   folder scanner + selective transcoder
|-- keep_one_audio.bat           single-file audio track extractor
|-- make_compatible.bat          original single-file checker/transcoder
|-- README.md
|-- LICENSE
|-- .gitignore                   excludes *.exe and media files
`-- docs/
    |-- BeginnerGuide.md
    `-- DeveloperGuide.md
```

## 3. Architecture: batch launcher + embedded PowerShell

`scan_folder_compatible.bat` and `keep_one_audio.bat` are each a **single file with two parts**: a few lines of batch at the top, and PowerShell code below a marker. Batch alone is fragile with characters such as `&`, `!`, `%`, `^` and brackets in file names, and clumsy for loops, string handling and JSON. PowerShell handles these correctly, while a `.bat` extension keeps the tool double-clickable with no execution-policy prompts and no extra file.

### The launcher

```bat
@echo off
setlocal
title ...
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c = Get-Content -LiteralPath $env:SELF -Raw; $i = $c.IndexOf('#PS'+'START'); Invoke-Expression $c.Substring($i)"
echo.
pause
exit /b

#PSSTART
... PowerShell code ...
```

How it works:

1. `set "SELF=%~f0"` stores the script's full path in an environment variable. PowerShell reads it as `$env:SELF`, which avoids quoting problems in paths containing spaces or apostrophes.
2. PowerShell reads the whole `.bat` file as text, finds the marker, and runs everything from the marker onward with `Invoke-Expression`.
3. The marker is written as `'#PS'+'START'` inside the launcher line so the launcher's own text does not contain the literal marker. Otherwise `IndexOf` would match the launcher line first.
4. `exit /b` stops `cmd.exe` before it reaches the PowerShell section. `cmd` reads a script line by line as it executes, so it never parses the PowerShell text.
5. Nothing is written to disk and no `.ps1` is run, so PowerShell's execution policy does not apply. `-ExecutionPolicy Bypass` is harmless belt-and-braces.
6. `pause` keeps the window open so the user can read the final output.

### Script-level conventions

- `$ErrorActionPreference = 'Continue'`. Windows PowerShell 5.1 can turn native-command stderr output into terminating errors under `Stop`, and ffmpeg writes progress to stderr.
- `return` at top level ends the `Invoke-Expression` run (used when ffmpeg is missing).
- File operations use `-LiteralPath` and `[System.IO.File]::Move(...)` instead of `Rename-Item`, to avoid wildcard and bracket interpretation in names such as `Movie [1080p].mkv`.
- Tools are located by `Find-Tool`: `<script dir>\<name>.exe` first, then `Get-Command`.

## 4. scan_folder_compatible.bat

### Flow

```
prompt for folder  ->  validate  ->  offer to delete leftover partial files
   ->  Invoke-Scan (probe + rename)  ->  summary
   ->  loop: Get-Pending -> numbered list -> parse selection -> Invoke-Transcode
   ->  "Scan another folder?" -> repeat or exit
```

### Functions

| Function | Responsibility |
|----------|----------------|
| `Find-Tool` | Locate `ffmpeg.exe` / `ffprobe.exe`. |
| `Get-Codecs` | Returns `{ Video: string, Audio: string[] }` from two ffprobe calls. |
| `Test-Compat` | `true` only if video is `h264` and every audio codec is `aac`. |
| `Format-Codecs` | Human-readable codec summary for console output. |
| `Invoke-Scan` | Lists direct-child files with a video extension, skips tagged ones, probes, renames, returns counters. |
| `Get-Pending` | Files tagged `_not_compatible` that have no matching `<base>_compatible.mp4` yet. |
| `Invoke-Transcode` | Builds and runs the ffmpeg command for one file; renames the output on success. |

### Scan rules

- **Extensions** (`$VideoExt`): `.mp4 .mkv .avi .mov .wmv .flv .webm .m4v .ts .m2ts .mts .mpg .mpeg .3gp .vob .ogv`. Compared in lower case.
- **Scope:** `Get-ChildItem -LiteralPath $Folder -File`, non-recursive.
- **Skip rule:** base name matches `(?i)_(not_)?compatible$`. Skipped files are counted but not probed. This also skips `..._underTranscoding_not_compatible.*` temporary files, because they end in `_not_compatible`.
- **Unreadable:** if ffprobe returns no video codec, the file is reported as unreadable and left untouched.
- **Rename:** `<base>_compatible<ext>` or `<base>_not_compatible<ext>`. If the target name already exists, nothing is renamed and the file is counted as an error. Rename exceptions (for example a locked file) are caught and counted.
- **Scan never transcodes.** It only probes and renames.

### Pending list

`Get-Pending` returns files whose base name ends in `_not_compatible`, excluding `_underTranscoding_not_compatible` temporaries and excluding any file whose `<base>_compatible.mp4` already exists. It recomputes after every transcode batch, so the list shrinks as work completes and failures stay listed. Because it reads the folder rather than session memory, files tagged in earlier runs are included.

### Selection parsing

Input is `all`, or a list split on `[,\s]+`. Each token must parse as an integer within `1..count`. Any invalid token rejects the whole input and re-prompts. Duplicates are removed with `Select-Object -Unique`.

### Transcode logic

For one file, `Invoke-Transcode`:

1. Derives `$base` by stripping `_not_compatible` from the base name.
2. Defines `$final = <base>_compatible.mp4` and `$temp = <base>_underTranscoding_not_compatible.mp4`. If `$final` exists, it skips the file.
3. Re-probes the file with `Get-Codecs`.
4. Video: if the codec is not `h264`, use `-c:v libx264 -preset medium -crf 20`, otherwise `-c:v copy`.
5. Audio, **per track** `k` in probe order: if the codec is not `aac`, use `-c:a:k aac -b:a:k 192k -ar:a:k 48000`, otherwise `-c:a:k copy`.
6. Runs ffmpeg writing to `$temp`. On exit code 0, moves `$temp` to `$final`. On failure, deletes `$temp`.

Resulting command shape for a file with H.264 video and two audio tracks (AC-3, AAC):

```text
ffmpeg -hide_banner -y -i "<in>" -map 0:v:0 -map 0:a? ^
  -c:v copy ^
  -c:a:0 aac -b:a:0 192k -ar:a:0 48000 ^
  -c:a:1 copy ^
  -sn -dn "<base>_underTranscoding_not_compatible.mp4"
```

`-map 0:a?` maps all audio streams, and the trailing `?` makes the mapping optional so a file with no audio does not error. The per-stream indices `a:k` line up with the order ffprobe reports audio streams.

The output is always `.mp4`. A leftover `_underTranscoding_not_compatible.mp4` after an interrupted run is detected at the start of the next scan and the user is asked whether to delete it.

## 5. keep_one_audio.bat

### Flow

```
prompt for file -> ffprobe audio streams as JSON -> list tracks
  -> prompt for track number -> ffmpeg stream copy -> rename on success
```

### Probe

```text
ffprobe -v error -select_streams a ^
  -show_entries "stream=index,codec_name,channels:stream_tags=language,title" ^
  -of json "<file>"
```

The output is parsed with `ConvertFrom-Json`. Missing language shows as `unknown`. `channels` is mapped to `mono`, `stereo`, `5.1` or `7.1`, otherwise `N ch`. If JSON parsing fails (for example, a file with tag keys differing only by case, which Windows PowerShell 5.1 can reject), the tool treats the file as having no readable audio and says so.

### Extraction

For the 0-based audio position `k` the user selected:

```text
ffmpeg -hide_banner -y -i "<in>" ^
  -map 0:v:0 -map 0:a:k ^
  -c copy -disposition:a:0 default ^
  -sn -dn "<base>_underProcessing<ext>"
```

- Streams are **copied**, so there is no quality loss and the run takes seconds.
- Only the first video stream and the selected audio stream are mapped. All other streams are dropped.
- The kept audio stream is flagged `default`.
- The output keeps the **source extension**. The result is renamed to `<base>_1audio<ext>` after a successful run. If the target exists the tool refuses to overwrite it. On failure the temporary file is deleted.
- Files with zero or one audio track are reported and not processed.

Because the output container matches the source, stream copy is generally safe. A source whose audio codec cannot be stored in its own container is not a concern, since it was already stored there.

## 6. make_compatible.bat

The original single-file tool, kept for one-off use.

- Asks for one file path, strips surrounding quotes, and probes the first video and first audio stream with ffprobe.
- `NEED_V` is set unless the video codec is `h264`, and `NEED_A` is set unless the audio codec is `aac`.
- If neither is set it reports `Already compatible` and exits.
- Otherwise it runs `ffmpeg -y -i "<in>" -map 0:v:0 -map 0:a:0? <video opts> <audio opts> "<name>_compatible.mp4"`, copying whichever stream is already compatible.
- It does not rename the input, handles only the first audio track, and is pure batch with delayed expansion, so file names containing `!` may misbehave. Prefer `scan_folder_compatible.bat` for anything beyond a quick check.

## 7. ffprobe and ffmpeg commands reference

You can reproduce every check by hand. Replace `input.mkv` with your file.

**First video codec**

```text
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 input.mkv
```

**All audio codecs, one per line, in stream order**

```text
ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 input.mkv
```

**Full stream overview**

```text
ffprobe -v error -show_entries stream=index,codec_type,codec_name,profile,pix_fmt,width,height,r_frame_rate,channels:stream_tags=language,title -of json input.mkv
```

**Convert only what's needed (example: HEVC video, AC-3 + AAC audio)**

```text
ffmpeg -i input.mkv -map 0:v:0 -map 0:a? ^
  -c:v libx264 -preset medium -crf 20 ^
  -c:a:0 aac -b:a:0 192k -ar:a:0 48000 ^
  -c:a:1 copy ^
  -sn -dn output.mp4
```

**Keep audio track 3 only**

```text
ffmpeg -i input.mkv -map 0:v:0 -map 0:a:2 -c copy -disposition:a:0 default -sn -dn output.mkv
```

## 8. Naming conventions and state

The tools are **stateless**. All state lives in file names, so there is no database, config file or log to corrupt.

| Name pattern | Meaning |
|--------------|---------|
| `X_compatible.ext` | Passed the check, or is a converted output (`X_compatible.mp4`). Skipped on later scans. |
| `X_not_compatible.ext` | Failed the check. Kept as the original after conversion. Skipped on later scans, listed as pending until `X_compatible.mp4` exists. |
| `X_underTranscoding_not_compatible.mp4` | In-progress or interrupted conversion output. Never mistaken for a finished file. |
| `X_1audio.ext` | Output of `keep_one_audio.bat`. Carries neither tag, so the scanner will probe and tag it on its next run. |
| `X_underProcessing.ext` | In-progress output of `keep_one_audio.bat`. Delete by hand if a run was interrupted. |

If you rename the tags, update every place they occur: the skip regex in `Invoke-Scan`, the two regexes in `Get-Pending`, the strip regex in `Invoke-Transcode`, the leftover detection in the main loop, and the README/guides.

## 9. Customisation recipes

All edits are in the PowerShell section of the relevant `.bat` file.

**Add or remove scanned extensions**: edit `$VideoExt` near the top of `scan_folder_compatible.bat`.

**Change the target video quality**: in `Invoke-Transcode`, adjust `'-preset', 'medium', '-crf', '20'`. Lower CRF gives higher quality and larger files; slower presets give smaller files at the same quality but take longer.

**Change the audio bitrate or sample rate**: edit `'-b:a:$k'`, `'192k'` and `'48000'`.

**Accept more audio codecs as compatible** (for example AC-3): change the rule in `Test-Compat` and the per-track test in `Invoke-Transcode` together, otherwise scanning and conversion disagree. Verify your projector actually plays them first.

**Add a pixel-format and profile check** (rejects 10-bit and High 4:4:4 H.264, which many projectors can't play):

1. Extend the video probe in `Get-Codecs`:
   ```text
   -show_entries stream=codec_name,profile,pix_fmt -of csv=p=0
   ```
   The output order is `codec_name,profile,pix_fmt`.
2. Add `Profile` and `PixFmt` to the returned object.
3. In `Test-Compat`, require `PixFmt -eq 'yuv420p'` as well.
4. In `Invoke-Transcode`, add `'-pix_fmt','yuv420p'` to `$vopts`. Note that a file that fails only on pixel format must be re-encoded, so the `-c:v copy` branch must not be used for it.

**Add a resolution limit**: probe `width,height` the same way, treat anything above your projector's native resolution as incompatible, and add `-vf scale=-2:1080` (or your limit) to the re-encode branch.

**Change the temporary or output names**: edit `$final` and `$temp` in `Invoke-Transcode`, then see section 8 for every place that depends on them.

**Recurse into subfolders**: add `-Recurse` to the `Get-ChildItem` calls in `Invoke-Scan`, `Get-Pending` and the leftover check, and use `$f.DirectoryName` instead of `$Folder` when building target paths in `Invoke-Scan`, `Get-Pending` and `Invoke-Transcode`.

## 10. Testing

Generate small synthetic files with ffmpeg. Run these in a scratch folder:

```text
:: compatible: H.264 + AAC
ffmpeg -f lavfi -i testsrc=duration=5:size=640x360:rate=25 -f lavfi -i sine=frequency=440:duration=5 ^
  -c:v libx264 -pix_fmt yuv420p -c:a aac ok_h264_aac.mp4

:: incompatible: MPEG-4 video + AC-3 audio
ffmpeg -f lavfi -i testsrc=duration=5:size=640x360:rate=25 -f lavfi -i sine=frequency=440:duration=5 ^
  -c:v mpeg4 -c:a ac3 bad_mpeg4_ac3.mkv

:: video fine, one bad audio track among two (tests per-track logic and keep_one_audio)
ffmpeg -f lavfi -i testsrc=duration=5:size=640x360:rate=25 ^
  -f lavfi -i sine=frequency=440:duration=5 -f lavfi -i sine=frequency=880:duration=5 ^
  -map 0 -map 1 -map 2 -c:v libx264 -pix_fmt yuv420p -c:a:0 ac3 -c:a:1 aac ^
  -metadata:s:a:0 language=eng -metadata:s:a:1 language=hin multi_audio.mkv
```

### Manual test checklist

Scanner:
- [ ] `ok_h264_aac.mp4` is renamed `_compatible`.
- [ ] `bad_mpeg4_ac3.mkv` and `multi_audio.mkv` are renamed `_not_compatible` (the latter because one audio track is AC-3).
- [ ] A second run skips all three files.
- [ ] A subfolder's videos are ignored.
- [ ] A non-video file (for example `notes.txt`) is ignored.
- [ ] A zero-byte `fake.mp4` is reported UNREADABLE and left untouched.
- [ ] Choosing `all` converts both pending files; outputs are `_compatible.mp4` and originals remain `_not_compatible`.
- [ ] After conversion, `multi_audio_compatible.mp4` has video copied and audio track 1 re-encoded to AAC (`ffprobe` confirms both are `aac`).
- [ ] Interrupting a conversion (close the window) leaves `..._underTranscoding_not_compatible.mp4`; the next scan offers to delete it.
- [ ] File names with `&`, `!`, `%`, `[` `]` and spaces are handled.

Keep one audio:
- [ ] `multi_audio.mkv` lists two tracks with `eng` and `hin`.
- [ ] Choosing 2 produces `multi_audio_1audio.mkv` with a single AAC track.
- [ ] Running it again refuses to overwrite the output.
- [ ] A one-track file reports that nothing needs doing.

## 11. Editing rules and gotchas

- **Line endings:** save `.bat` files with **CRLF** line endings. `cmd.exe` can misbehave with LF-only files. Configure your editor or Git (`* text=auto eol=crlf` in `.gitattributes`, if you want this enforced).
- **Encoding:** keep the files plain **ASCII**. Non-ASCII characters can break the `cmd` stage or the `Get-Content` read.
- **The marker:** the literal text `#PSSTART` must appear only once, at the start of the PowerShell section, and the launcher must keep building it as `'#PS'+'START'`.
- **Nothing after `exit /b` may be batch.** Everything past it is PowerShell and must not be treated as batch by `cmd`.
- **PowerShell version:** write for 5.1. Avoid features that exist only in PowerShell 7 (for example the ternary operator `? :`). The scripts use `$(if ...)` and `if` expressions instead.
- **Native command output:** capture ffprobe output with `& $ffprobe ... 2>$null`, then trim, because lines may carry trailing commas or whitespace.
- **Console prompts:** `Read-Host` input is used as-is, so strip quotes and whitespace (the scripts do) before testing paths.

## 12. Known limitations

- Codec-only compatibility: profile, bit depth, resolution, frame rate and bitrate are not checked.
- `-crf 20` with `-preset medium` is a good general default but not tuned to a specific projector's bitrate ceiling.
- Only the first video stream is kept. Attached pictures such as cover art are not handled specially.
- Subtitles and data streams are always dropped.
- The scanner does not recurse.
- `make_compatible.bat` is the older, less robust implementation and may mishandle `!` in file names.
- The compatibility rule was built around one projector (PANSEBA). Others may need a different rule.
- Windows only (see section 1).

## 13. Contributing

Issues and pull requests are welcome. For changes, please:

1. Keep each `.bat` self-contained (launcher + PowerShell, no extra files).
2. Preserve CRLF line endings and ASCII-only content.
3. Run the manual test checklist above and note the results in the pull request.
4. Update the Beginner Guide if user-visible behaviour or prompts change, and this guide if the logic or naming changes.
