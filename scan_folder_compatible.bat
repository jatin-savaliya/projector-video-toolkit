@echo off
setlocal
title Projector Compatibility Scanner
rem ============================================================
rem  Folder scanner + transcoder for the PANSEBA projector.
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

$VideoExt  = @('.mp4','.mkv','.avi','.mov','.wmv','.flv','.webm','.m4v','.ts','.m2ts','.mts','.mpg','.mpeg','.3gp','.vob','.ogv')
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

# ---------- Codec detection ----------
function Get-Codecs([string]$Path) {
    $v = @(& $ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 $Path 2>$null |
        ForEach-Object { "$_".Trim().Trim(',') } | Where-Object { $_ })
    $a = @(& $ffprobe -v error -select_streams a -show_entries stream=codec_name -of csv=p=0 $Path 2>$null |
        ForEach-Object { "$_".Trim().Trim(',') } | Where-Object { $_ })
    [pscustomobject]@{
        Video = $(if ($v.Count) { $v[0] } else { '' })
        Audio = $a
    }
}

# Compatible = video is h264 AND every audio track is aac
function Test-Compat($c) {
    if ($c.Video -ne 'h264') { return $false }
    foreach ($ac in $c.Audio) { if ($ac -ne 'aac') { return $false } }
    return $true
}

function Format-Codecs($c) {
    $aud = if ($c.Audio.Count) { $c.Audio -join '+' } else { 'none' }
    return ('video: {0} | audio: {1}' -f $c.Video, $aud)
}

# ---------- Scan: check + rename ----------
function Invoke-Scan([string]$Folder) {
    $files = @(Get-ChildItem -LiteralPath $Folder -File |
        Where-Object { $VideoExt -contains $_.Extension.ToLower() } | Sort-Object Name)
    $r = @{ Total = $files.Count; Skipped = 0; Compatible = 0; NotCompatible = 0; Unreadable = 0; Errors = 0 }
    $i = 0
    foreach ($f in $files) {
        $i++
        if ($f.BaseName -match '(?i)_(not_)?compatible$') { $r.Skipped++; continue }

        Write-Host ('[{0}/{1}] {2} ... ' -f $i, $files.Count, $f.Name) -NoNewline
        $c = Get-Codecs $f.FullName
        if (-not $c.Video) {
            Write-Host 'UNREADABLE (left untouched)' -ForegroundColor Yellow
            $r.Unreadable++
            continue
        }

        $ok      = Test-Compat $c
        $tag     = if ($ok) { '_compatible' } else { '_not_compatible' }
        $newPath = Join-Path $Folder ($f.BaseName + $tag + $f.Extension)

        if (Test-Path -LiteralPath $newPath) {
            Write-Host 'target name already exists, not renamed' -ForegroundColor Yellow
            $r.Errors++
            continue
        }
        try {
            [System.IO.File]::Move($f.FullName, $newPath)
            if ($ok) {
                Write-Host ('COMPATIBLE  (' + (Format-Codecs $c) + ')') -ForegroundColor Green
                $r.Compatible++
            } else {
                Write-Host ('NOT COMPATIBLE  (' + (Format-Codecs $c) + ')') -ForegroundColor Red
                $r.NotCompatible++
            }
        } catch {
            Write-Host ('rename failed: ' + $_.Exception.Message) -ForegroundColor Yellow
            $r.Errors++
        }
    }
    return $r
}

# ---------- Files still waiting for transcoding ----------
function Get-Pending([string]$Folder) {
    Get-ChildItem -LiteralPath $Folder -File | Where-Object {
        ($VideoExt -contains $_.Extension.ToLower()) -and
        ($_.BaseName -match '(?i)_not_compatible$') -and
        ($_.BaseName -notmatch '(?i)_underTranscoding_not_compatible$')
    } | Where-Object {
        $b = $_.BaseName -replace '(?i)_not_compatible$', ''
        -not (Test-Path -LiteralPath (Join-Path $Folder ($b + '_compatible.mp4')))
    } | Sort-Object Name
}

# ---------- Transcode one file (same logic as before, per audio track) ----------
function Invoke-Transcode($File) {
    $dir   = $File.DirectoryName
    $base  = $File.BaseName -replace '(?i)_not_compatible$', ''
    $final = Join-Path $dir ($base + '_compatible.mp4')
    $temp  = Join-Path $dir ($base + '_underTranscoding_not_compatible.mp4')

    Write-Host ''
    Write-Host ('=== ' + $File.Name) -ForegroundColor Cyan

    if (Test-Path -LiteralPath $final) {
        Write-Host 'Skipped: a _compatible.mp4 with this name already exists.' -ForegroundColor Yellow
        return
    }

    $c = Get-Codecs $File.FullName
    if (-not $c.Video) {
        Write-Host 'Skipped: could not read the file.' -ForegroundColor Yellow
        return
    }
    Write-Host (Format-Codecs $c)

    if ($c.Video -ne 'h264') {
        $vopts = @('-c:v', 'libx264', '-preset', 'medium', '-crf', '20')
        Write-Host ('Video needs re-encoding: ' + $c.Video + ' -> H.264')
    } else {
        $vopts = @('-c:v', 'copy')
        Write-Host 'Video already H.264 - copying.'
    }

    $aopts = @()
    for ($k = 0; $k -lt $c.Audio.Count; $k++) {
        if ($c.Audio[$k] -ne 'aac') {
            $aopts += @("-c:a:$k", 'aac', "-b:a:$k", '192k', "-ar:a:$k", '48000')
            Write-Host ('Audio track ' + ($k + 1) + ' needs re-encoding: ' + $c.Audio[$k] + ' -> AAC')
        } else {
            $aopts += @("-c:a:$k", 'copy')
            Write-Host ('Audio track ' + ($k + 1) + ' already AAC - copying.')
        }
    }

    $ffArgs = @('-hide_banner', '-y', '-i', $File.FullName, '-map', '0:v:0', '-map', '0:a?') +
              $vopts + $aopts + @('-sn', '-dn', $temp)

    Write-Host 'Transcoding... (writing to a temporary name until finished)'
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $ffmpeg $ffArgs
    $code = $LASTEXITCODE
    $sw.Stop()

    if ($code -eq 0 -and (Test-Path -LiteralPath $temp)) {
        try {
            [System.IO.File]::Move($temp, $final)
            Write-Host ('SUCCESS in {0:N1} min: {1}' -f $sw.Elapsed.TotalMinutes, (Split-Path -Leaf $final)) -ForegroundColor Green
        } catch {
            Write-Host ('Transcode finished but final rename failed: ' + $_.Exception.Message) -ForegroundColor Red
        }
    } else {
        Write-Host 'TRANSCODE FAILED. See the ffmpeg error above.' -ForegroundColor Red
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
    }
}

# ---------- Main ----------
while ($true) {
    Write-Host ''
    $in = Read-Host 'Paste the full path of the video FOLDER (press Enter to exit)'
    $in = ($in -replace '"', '').Trim()
    if (-not $in) { break }
    if (-not (Test-Path -LiteralPath $in -PathType Container)) {
        Write-Host 'Folder not found.' -ForegroundColor Red
        continue
    }
    $folder = (Resolve-Path -LiteralPath $in).ProviderPath

    # Leftovers from an interrupted transcode
    $left = @(Get-ChildItem -LiteralPath $folder -File |
        Where-Object { $_.BaseName -match '(?i)_underTranscoding_not_compatible$' })
    if ($left.Count) {
        Write-Host ''
        Write-Host 'Incomplete files from an interrupted transcode:' -ForegroundColor Yellow
        foreach ($l in $left) { Write-Host ('  ' + $l.Name) }
        $ans = Read-Host 'Delete these incomplete files? (y/N)'
        if ($ans -match '^(?i)y') {
            foreach ($l in $left) { Remove-Item -LiteralPath $l.FullName -Force -ErrorAction SilentlyContinue }
            Write-Host 'Deleted.'
        }
    }

    Write-Host ''
    Write-Host 'Scanning...'
    $r = Invoke-Scan $folder

    Write-Host ''
    Write-Host '---------------- SUMMARY ----------------'
    Write-Host ('Video files in folder        : ' + $r.Total)
    Write-Host ('Skipped (already tagged)     : ' + $r.Skipped)
    Write-Host ('Renamed _compatible          : ' + $r.Compatible)
    Write-Host ('Renamed _not_compatible      : ' + $r.NotCompatible)
    if ($r.Unreadable) { Write-Host ('Unreadable (untouched)       : ' + $r.Unreadable) }
    if ($r.Errors)     { Write-Host ('Rename problems              : ' + $r.Errors) }
    Write-Host '-----------------------------------------'

    # Pick files to transcode
    while ($true) {
        $pending = @(Get-Pending $folder)
        if ($pending.Count -eq 0) {
            Write-Host ''
            Write-Host 'No _not_compatible files waiting for transcoding.' -ForegroundColor Green
            break
        }
        Write-Host ''
        Write-Host 'Files waiting for transcoding:'
        for ($n = 0; $n -lt $pending.Count; $n++) {
            Write-Host ('  {0,3}. {1}  ({2} MB)' -f ($n + 1), $pending[$n].Name, [math]::Round($pending[$n].Length / 1MB, 1))
        }
        $sel = (Read-Host "Enter numbers (e.g. 1,3,5), 'all', or press Enter to skip").Trim()
        if (-not $sel) { break }

        $idx = @()
        if ($sel -ieq 'all') {
            $idx = 1..$pending.Count
        } else {
            $bad = $false
            foreach ($t in @($sel -split '[,\s]+' | Where-Object { $_ })) {
                $num = 0
                if ([int]::TryParse($t, [ref]$num) -and $num -ge 1 -and $num -le $pending.Count) { $idx += $num }
                else { $bad = $true }
            }
            if ($bad -or $idx.Count -eq 0) {
                Write-Host 'Invalid selection, try again.' -ForegroundColor Yellow
                continue
            }
        }
        foreach ($num in ($idx | Select-Object -Unique)) { Invoke-Transcode $pending[$num - 1] }
    }

    Write-Host ''
    $again = Read-Host 'Scan another folder? (y/N)'
    if ($again -notmatch '^(?i)y') { break }
}
