@echo off
rem QBladeCE MSVC fixes - run from patches\ or repo root
cd /d "%~dp0.."
where python >nul 2>nul && (python patches\fix_msvc.py & goto done)
where python3 >nul 2>nul && (python3 patches\fix_msvc.py & goto done)
"C:\Python314\python.exe" patches\fix_msvc.py
:done
pause
