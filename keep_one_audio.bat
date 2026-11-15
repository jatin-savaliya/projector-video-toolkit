@echo off
setlocal
title Keep One Audio Track
rem ============================================================
rem  Lists all audio tracks of a video, you pick ONE, and a new
rem  file is written with only that track. Video is copied as-is
rem  (no re-encoding), subtitles are dropped, original is untouched.
rem  Single file: batch launcher on top, PowerShell logic below.
rem  Needs ffmpeg.exe + ffprobe.exe in this folder or in PATH.
rem ============================================================
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$c = Get-Content -LiteralPath $env:SELF -Raw; $i = $c.IndexOf('#PS'+'START'); Invoke-Expression $c.Substring($i)"
echo.
pause
exit /b

#PSSTART
$ErrorActionPreference = 'Continue'
$ScriptDir = Split-Path -Parent $env:SELF

function Find-Tool([string]$Name) {
    $local = Join-Path $ScriptDir ($Name + '.exe')
    if (Test-Path -LiteralPath $local) { return $local }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$ffmpeg  = Find-Tool 'ffmpeg'
$ffprobe = Find-Tool 'ffprobe'
if (-not $ffmpeg -or -not $ffprobe) {
    Write-Host 'ERROR: ffmpeg.exe / ffprobe.exe not found.' -ForegroundColor Red
    Write-Host 'Place them in the same folder as this script, or add their folder to PATH.'
    return
}

function Format-Channels($n) {
    switch ([int]$n) {
        1 { return 'mono' }
        2 { return 'stereo' }
        6 { return '5.1' }
        8 { return '7.1' }
        default { return ('{0} ch' -f $n) }
    }
}

while ($true) {
    Write-Host ''
    $in = Read-Host 'Paste the full path of the video FILE (press Enter to exit)'
    $in = ($in -replace '"', '').Trim()
    if (-not $in) { break }
    if (-not (Test-Path -LiteralPath $in -PathType Leaf)) {
        Write-Host 'File not found.' -ForegroundColor Red
        continue
    }
    $file = Get-Item -LiteralPath $in

    # List audio tracks
    $json = (& $ffprobe -v error -select_streams a -show_entries 'stream=index,codec_name,channels:stream_tags=language,title' -of json $file.FullName 2>$null | Out-String)
    $streams = @()
    try { $streams = @(($json | ConvertFrom-Json).streams) } catch { $streams = @() }

    if ($streams.Count -eq 0) {
        Write-Host 'No audio tracks found (or file could not be read).' -ForegroundColor Yellow
        continue
    }
    if ($streams.Count -eq 1) {
        Write-Host 'This file already has only one audio track. Nothing to do.' -ForegroundColor Green
        continue
    }

    Write-Host ''
    Write-Host ('Audio tracks in: ' + $file.Name)
    for ($k = 0; $k -lt $streams.Count; $k++) {
        $s     = $streams[$k]
        $lang  = if ($s.tags.language) { $s.tags.language } else { 'unknown' }
        $title = if ($s.tags.title) { ' - ' + $s.tags.title } else { '' }
        Write-Host ('  {0,2}. {1}{2}  ({3}, {4})' -f ($k + 1), $lang, $title, $s.codec_name, (Format-Channels $s.channels))
    }

    $sel = (Read-Host 'Enter the number of the track to KEEP (press Enter to cancel)').Trim()
    if (-not $sel) { continue }
    $num = 0
    if (-not ([int]::TryParse($sel, [ref]$num) -and $num -ge 1 -and $num -le $streams.Count)) {
        Write-Host 'Invalid number.' -ForegroundColor Yellow
        continue
    }
    $k = $num - 1

    $dir   = $file.DirectoryName
    $final = Join-Path $dir ($file.BaseName + '_1audio' + $file.Extension)
    $temp  = Join-Path $dir ($file.BaseName + '_underProcessing' + $file.Extension)

    if (Test-Path -LiteralPath $final) {
        Write-Host ('Output already exists, not overwritten: ' + (Split-Path -Leaf $final)) -ForegroundColor Yellow
        continue
    }

    Write-Host ''
    Write-Host ('Keeping track {0}. Writing (no re-encoding)...' -f $num)
    $ffArgs = @('-hide_banner', '-y', '-i', $file.FullName,
                '-map', '0:v:0', '-map', "0:a:$k",
                '-c', 'copy', '-disposition:a:0', 'default',
                '-sn', '-dn', $temp)
    & $ffmpeg $ffArgs
    $code = $LASTEXITCODE

    if ($code -eq 0 -and (Test-Path -LiteralPath $temp)) {
        try {
            [System.IO.File]::Move($temp, $final)
            Write-Host ('SUCCESS: ' + (Split-Path -Leaf $final)) -ForegroundColor Green
            Write-Host ('Original kept untouched: ' + $file.Name)
        } catch {
            Write-Host ('Finished, but final rename failed: ' + $_.Exception.Message) -ForegroundColor Red
        }
    } else {
        Write-Host 'FAILED. See the ffmpeg error above.' -ForegroundColor Red
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    }
}
