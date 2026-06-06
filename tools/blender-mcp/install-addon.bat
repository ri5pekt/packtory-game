@echo off
REM Install BlenderMCP addon into the user's Blender scripts folder.
REM Run once, then enable in Blender: Edit > Preferences > Add-ons > BlenderMCP

set "ADDON_SRC=%~dp0addon.py"
set "BLENDER_APPDATA=%APPDATA%\Blender Foundation\Blender"

if not exist "%ADDON_SRC%" (
  echo ERROR: addon.py not found next to this script.
  exit /b 1
)

if not exist "%BLENDER_APPDATA%" (
  echo ERROR: Blender app data not found at:
  echo   %BLENDER_APPDATA%
  echo Open Blender at least once, then run this again.
  exit /b 1
)

set "INSTALLED=0"
for /d %%V in ("%BLENDER_APPDATA%\*") do (
  set "DEST=%%V\scripts\addons\blender_mcp"
  if not exist "%%V\scripts\addons" mkdir "%%V\scripts\addons"
  if not exist "!DEST!" mkdir "!DEST!"
  copy /Y "%ADDON_SRC%" "!DEST!\__init__.py" >nul
  echo Installed addon for Blender %%~nxV
  set "INSTALLED=1"
)

if "%INSTALLED%"=="0" (
  echo No Blender version folders found under %BLENDER_APPDATA%
  exit /b 1
)

echo.
echo Done. In Blender:
echo   1. Edit - Preferences - Add-ons - search "BlenderMCP" - enable
echo   2. Press N in 3D view - BlenderMCP tab - Connect
echo   3. Restart Cursor if MCP still shows an error
