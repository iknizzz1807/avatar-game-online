@echo off
setlocal

:: ================================================================
::  run_palette_remap.bat
::  Launches Aseprite in headless mode to run palette_remap.lua
::
::  The Lua script handles EVERYTHING:
::    - Opens each PNG independently (no sequence grouping!)
::    - Remaps pixels to your palette (edit TARGET_PALETTE in the .lua)
::    - Trims transparent borders to fit content exactly
::    - Saves results to the output\ sub-folder
:: ================================================================

:: ── CONFIGURE THESE TWO PATHS ────────────────────────────────────────────────

:: Path to your Aseprite executable
set ASEPRITE="D:\Games\Steam\steamapps\common\Aseprite\Aseprite.exe"

:: Path to the Lua script (same folder as this .bat by default)
set SCRIPT="%~dp0palette_remap.lua"

:: ─────────────────────────────────────────────────────────────────────────────

if not exist %ASEPRITE% (
    echo ERROR: Aseprite not found at %ASEPRITE%
    echo Please edit ASEPRITE path in this .bat file.
    pause
    exit /b 1
)

if not exist %SCRIPT% (
    echo ERROR: palette_remap.lua not found at %SCRIPT%
    pause
    exit /b 1
)

echo Running palette remap via Lua script...
echo (Edit TARGET_PALETTE inside palette_remap.lua to change colors)
echo.

%ASEPRITE% -b --script %SCRIPT%

echo.
echo Aseprite finished. Check the output\ folder.
pause
