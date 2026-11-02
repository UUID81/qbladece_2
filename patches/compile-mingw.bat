@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0\.."
echo === compile MinGW: repertoire %CD%

set "QMAKE="
for %%Q in (
  "C:\Qt\5.15.2\mingw81_64\bin\qmake.exe"
  "C:\Qt\5.15.3\mingw81_64\bin\qmake.exe"
  "C:\Qt\5.15.2\mingw_64\bin\qmake.exe"
  "C:\Qt\5.15.2\clang_64\bin\qmake.exe"
) do ( if exist %%~Q if "!QMAKE!"=="" set "QMAKE=%%~Q" )
if "%QMAKE%"=="" ( where qmake >nul 2>nul && set "QMAKE=qmake" )
if "%QMAKE%"=="" (
  echo ERREUR: qmake MinGW introuvable dans C:\Qt\5.15.2\mingw81_64\bin
  echo Installe le kit MinGW de Qt 5.15.2, par ex. avec:
  echo   C:\Python314\python.exe -m pip install aqtinstall
  echo   C:\Python314\python.exe -m aqt install-qt windows desktop 5.15.2 mingw81_64 -O C:\Qt
  pause
  exit /b 1
)
echo === qmake: %QMAKE%
for %%Q in ("%QMAKE%") do set "QTBIN=%%~dpQ"

set "MINGW_BIN="
for %%M in (
  "C:\Qt\Tools\mingw810_64\bin"
  "C:\Qt\Tools\mingw730_64\bin"
  "C:\Qt\Tools\mingw720_64\bin"
  "C:\msys64\mingw64\bin"
  "C:\msys64\usr\bin"
) do ( if exist %%~M if "!MINGW_BIN!"=="" set "MINGW_BIN=%%~M" )
if not "%MINGW_BIN%"=="" set "PATH=%PATH%;%MINGW_BIN%;%QTBIN%"
where g++
where mingw32-make
if errorlevel 1 ( echo ERREUR: mingw32-make introuvable & pause & exit /b 1 )

if /i "%1"=="clean" (
  mingw32-make distclean >nul 2>nul
  del /q Makefile .qmake.stash 2>nul
  rmdir /s /q release debug 2>nul
  echo clean OK
  pause
  exit /b 0
)

echo === qmake
"%QMAKE%" qblade.pro
if errorlevel 1 ( echo ERREUR: qmake a echoue & pause & exit /b 1 )

echo === mingw32-make (build.log, patience plusieurs minutes...)
mingw32-make -j%NUMBER_OF_PROCESSORS% > build.log 2>&1

echo ================= ERREURS (hors warnings) =================
findstr /i /c:"error" build.log | findstr /v /i "warning"
echo ================= FIN DU LOG =================
powershell -c "Get-Content build.log -Tail 15" 2>nul

echo === deploiement DLL Qt (windeployqt) + runtime MinGW
if exist release\QBladeCE.exe (
  if exist "%QTBIN%windeployqt.exe" "%QTBIN%windeployqt.exe" release\QBladeCE.exe
  if not "%MINGW_BIN%"=="" (
    copy /y "%MINGW_BIN%\libgcc_s_seh-1.dll" release\ >nul 2>nul
    copy /y "%MINGW_BIN%\libstdc++-6.dll" release\ >nul 2>nul
    copy /y "%MINGW_BIN%\libwinpthread-1.dll" release\ >nul 2>nul
  )
)

echo ================= RESULTAT =================
if exist release\QBladeCE.exe (
  echo SUCCES: release\QBladeCE.exe
  dir release\QBladeCE.exe
  echo --- DLL presentes dans release\:
  dir release\*.dll
) else (
  echo EXE MANQUANT: release\QBladeCE.exe - voir les erreurs ci-dessus
)
pause
