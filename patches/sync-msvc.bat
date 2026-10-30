@echo off
setlocal
cd /d "%~dp0\.."
echo === sync: git fetch + reset --hard origin/vibe/sensor-csv-658e4e
git fetch origin
if errorlevel 1 ( echo ERREUR git fetch & pause & exit /b 1 )
git reset --hard origin/vibe/sensor-csv-658e4e
if errorlevel 1 ( echo ERREUR git reset & pause & exit /b 1 )
echo === OK: HEAD =
git log -1 --oneline
echo === patchs python
where python >nul 2>nul
if not errorlevel 1 (
  python patches\fix_msvc.py
) else (
  where py >nul 2>nul
  if not errorlevel 1 (
    py patches\fix_msvc.py
  ) else (
    "C:\Python314\python.exe" patches\fix_msvc.py
  )
)
if errorlevel 1 ( echo ERREUR fix_msvc.py & pause & exit /b 1 )
where python >nul 2>nul
if not errorlevel 1 (
  python patches\fix_msvc_vpml.py
) else (
  where py >nul 2>nul
  if not errorlevel 1 (
    py patches\fix_msvc_vpml.py
  ) else (
    "C:\Python314\python.exe" patches\fix_msvc_vpml.py
  )
)
if errorlevel 1 ( echo ERREUR fix_msvc_vpml.py & pause & exit /b 1 )
echo === VERIF rapide des patchs poses
findstr /c:"__FUNCSIG__" src\VPML\Debug.h >nul && echo OK Debug.h FUNCSIG || echo MANQUANT Debug.h
findstr /c:"return Matrix(); }" src\VPML\ML_Euler.h >nul && echo OK ML_Euler.h returns || echo MANQUANT ML_Euler.h
findstr /c:"std::vector<Real> L(" src\VPML\ML_Box.cpp >nul && echo OK ML_Box.cpp L || echo MANQUANT ML_Box.cpp
findstr /c:"std::vector<char> VG(" src\VPML\Particle_Grid.cpp >nul && echo OK Particle_Grid.cpp VG || echo MANQUANT Particle_Grid.cpp
findstr /c:"/FI" qblade.pro >nul && echo OK qblade.pro /FI || echo MANQUANT qblade.pro /FI
echo === sync termine. Tu peux maintenant lancer compile-msvc.bat
pause
