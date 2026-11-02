@echo off
setlocal
cd /d "%~dp0\.."
echo === sync MinGW: git fetch + reset --hard origin/vibe/sensor-csv-658e4e
echo === (AUCUN patch MSVC applique: le build Windows supporte est MinGW, les DLL
rem   fournies dans libraries/libs_windows_64bit sont compilees avec MinGW)
git fetch origin
if errorlevel 1 ( echo ERREUR git fetch & pause & exit /b 1 )
git reset --hard origin/vibe/sensor-csv-658e4e
if errorlevel 1 ( echo ERREUR git reset & pause & exit /b 1 )
echo === OK: HEAD =
git log -1 --oneline
findstr /c:"copydlls.commands" qblade.pro >nul && echo OK qblade.pro copydlls || echo MANQUANT copydlls
findstr /c:"-fopenmp" qblade.pro >nul && echo OK qblade.pro -fopenmp || echo MANQUANT -fopenmp
echo === sync termine. Lance maintenant patches\compile-mingw.bat
pause
