@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0\.."
echo === repertoire: %CD%

set "VCVARS="
for %%P in (
  "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
  "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"
  "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat"
  "C:\Program Files\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
  "C:\Program Files\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"
  "C:\Program Files\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat"
) do (
  if exist %%~P if "!VCVARS!"=="" set "VCVARS=%%~P"
)
if "%VCVARS%"=="" (
  echo ERREUR: vcvarsall.bat introuvable. Ouvrir "Developer Command Prompt for VS 2019" dans le menu Demarrer.
  pause
  exit /b 1
)
echo === vcvarsall: %VCVARS%
call "%VCVARS%" amd64
where nmake
if errorlevel 1 (
  echo ERREUR: nmake toujours introuvable apres vcvarsall.
  pause
  exit /b 1
)

echo === git reset
git fetch origin
git reset --hard origin/vibe/sensor-csv-658e4e

echo === application des patchs MSVC
where python >nul 2>nul
if not errorlevel 1 (
  python patches\fix_msvc.py
  python patches\fix_msvc_vpml.py
) else (
  where py >nul 2>nul
  if not errorlevel 1 (
    py patches\fix_msvc.py
    py patches\fix_msvc_vpml.py
  ) else (
    if exist "C:\Python314\python.exe" (
      "C:\Python314\python.exe" patches\fix_msvc.py
      "C:\Python314\python.exe" patches\fix_msvc_vpml.py
    ) else (
      echo ERREUR: python introuvable.
      pause
      exit /b 1
    )
  )
)

echo === qmake
if exist "C:\Qt\5.15.2\msvc2019_64\bin\qmake.exe" (
  "C:\Qt\5.15.2\msvc2019_64\bin\qmake.exe" qblade.pro
) else (
  qmake qblade.pro
)
if errorlevel 1 (
  echo ERREUR: qmake a echoue.
  pause
  exit /b 1
)

echo === nmake (log dans build.log, patience plusieurs minutes...)
nmake /k > build.log 2>&1

echo ================= ERREURS (hors warnings) =================
findstr /i /c:"error" build.log | findstr /v /i "warning"
echo ================= FIN DU LOG =================
powershell -c "Get-Content build.log -Tail 15"
echo ================= RESULTAT =================
if exist release\QBladeCE.exe (
  echo SUCCES: release\QBladeCE.exe
  dir release\QBladeCE.exe
) else (
  echo EXE MANQUANT: release\QBladeCE.exe - voir les erreurs ci-dessus
)
pause
