@echo off
setlocal enabledelayedexpansion
title Projector Compatibility Checker / Transcoder

:: ============================================================
::  Checks video/audio codec of a file and transcodes it to
::  H.264 + AAC (MP4) ONLY if needed, for PANSEBA projector.
::  Requires ffmpeg + ffprobe available in PATH.
:: ============================================================

where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo ERROR: ffmpeg was not found on this system.
    echo Please download ffmpeg, and either:
    echo   1^) Add its "bin" folder to your PATH, OR
    echo   2^) Place ffmpeg.exe and ffprobe.exe in this same folder as this script.
    pause
    exit /b
)

echo.
set /p "INPUT=Paste the full path of the video file and press Enter: "

:: Strip surrounding quotes if pasted with them
set INPUT=%INPUT:"=%

if not exist "%INPUT%" (
    echo.
    echo File not found: "%INPUT%"
    pause
    exit /b
)

for %%F in ("%INPUT%") do (
    set "DIR=%%~dpF"
    set "NAME=%%~nF"
)

echo.
echo Analyzing codecs, please wait...

set "VTMP=%TEMP%\vcodec_check.txt"
set "ATMP=%TEMP%\acodec_check.txt"
del "%VTMP%" >nul 2>nul
del "%ATMP%" >nul 2>nul

ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "%INPUT%" > "%VTMP%" 2>nul
ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "%INPUT%" > "%ATMP%" 2>nul

set "VCODEC="
set "ACODEC="
set /p VCODEC=<"%VTMP%"
set /p ACODEC=<"%ATMP%"
del "%VTMP%" >nul 2>nul
del "%ATMP%" >nul 2>nul

echo.
echo Detected video codec : !VCODEC!
echo Detected audio codec : !ACODEC!
echo.

set "NEED_V=0"
set "NEED_A=0"

if /i not "!VCODEC!"=="h264" set "NEED_V=1"
if /i not "!ACODEC!"=="aac" set "NEED_A=1"

if "!NEED_V!"=="0" if "!NEED_A!"=="0" (
    echo RESULT: Already compatible. No action needed.
    echo.
    pause
    exit /b
)

set "OUTPUT=!DIR!!NAME!_compatible.mp4"

if "!NEED_V!"=="1" (
    set "VOPT=-c:v libx264 -preset medium -crf 20"
    echo Video needs re-encoding: !VCODEC! -^> H.264
) else (
    set "VOPT=-c:v copy"
    echo Video already compatible ^(H.264^) - will copy without re-encoding.
)

if "!NEED_A!"=="1" (
    set "AOPT=-c:a aac -b:a 192k -ar 48000"
    echo Audio needs re-encoding: !ACODEC! -^> AAC
) else (
    set "AOPT=-c:a copy"
    echo Audio already compatible ^(AAC^) - will copy without re-encoding.
)

echo.
echo Starting transcode. This may take a while for long/large files...
echo Output will be saved as:
echo   !OUTPUT!
echo.

ffmpeg -y -i "%INPUT%" -map 0:v:0 -map 0:a:0? !VOPT! !AOPT! "!OUTPUT!"

echo.
if errorlevel 1 (
    echo TRANSCODE FAILED. See the error above for details.
) else (
    echo SUCCESS: File is ready at:
    echo   !OUTPUT!
)

echo.
pause
