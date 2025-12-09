@echo off
setlocal EnableDelayedExpansion
chcp 65001 > nul
cd %temp%

:: Parameters
:: %1 = URL
:: %2 = old folder path
:: %3 = CopySettings flag (1 or 0)
:: %4 = DeleteOld flag (1 or 0)
:: %5 = Version number

if [%1]==[] (
    echo No URL parameter supplied.
    pause
    exit /b 1
)
if [%2]==[] (
    echo No target base folder parameter supplied.
    pause
    exit /b 1
)

set "url=%~1"
set "basefolder=%~2"
set "copysettings=%~3"
set "deleteold=%~4"
set "ver=%~5"

:: Compose new folder name with version appended
for %%I in ("%basefolder%") do set "parentfolder=%%~dpI"
set "parentfolder=%parentfolder:~0,-1%"
set "newfolder=%parentfolder%\Epics_GAG_macro_v%ver%"

:: Create new folder
if not exist "%newfolder%" mkdir "%newfolder%"

:: Copy settings.ini if requested and exists
if "%copysettings%"=="1" (
    if exist "%basefolder%\settings.ini" (
        echo Copying settings.ini to new folder...
        copy /Y "%basefolder%\settings.ini" "%newfolder%\settings.ini"
    ) else (
        echo No settings.ini found to copy.
    )
)

:: Download ZIP to temp
set "zipfile=%temp%\Epics_GAG_macro_v%ver%.zip"
echo Downloading %url%...

:: --- IMPROVEMENT: Enforce TLS 1.2 and Check for Download Success ---
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { (New-Object Net.WebClient).DownloadFile('%url%', '%zipfile%') } catch { exit 1 }"

if errorlevel 1 (
    echo.
    echo [ERROR] Download Failed! The URL returned 404 or the connection failed.
    echo URL attempted: %url%
    echo.
    pause
    exit /b 1
)

if not exist "%zipfile%" (
    echo [ERROR] Download appeared successful but ZIP file is missing.
    pause
    exit /b 1
)
echo Download complete.

:: Extract ZIP into new folder using WSF script
echo Extracting to "%newfolder%"...
cscript //nologo "%~f0?.wsf" "%newfolder%" "%zipfile%"

if errorlevel 1 (
    echo [ERROR] Extraction failed.
    pause
    exit /b 1
)

echo Extraction complete.

:: Delete ZIP
echo Deleting ZIP file...
del /f /q "%zipfile%"
echo ZIP deleted.

:: Start Macro
echo Starting Macro...
start "" "%newfolder%\scripts\AutoHotkey32.exe" "%newfolder%\scripts\Epic's_GAG_macro.ahk"

:: Delete old folder if requested
if "%deleteold%"=="1" (
    echo Deleting old folder "%basefolder%"...
    rd /s /q "%basefolder%"
    echo Old folder deleted.
)

exit /b 0

:: WSF script to extract ZIP
<job><script language="VBScript">
On Error Resume Next
set fso = CreateObject("Scripting.FileSystemObject")
set objShell = CreateObject("Shell.Application")
set FilesInZip = objShell.NameSpace(WScript.Arguments(1)).items
If Err.Number <> 0 Then
    WScript.Quit 1
End If
objShell.NameSpace(WScript.Arguments(0)).CopyHere FilesInZip, 20
set fso = nothing
set objShell = nothing
</script></job>