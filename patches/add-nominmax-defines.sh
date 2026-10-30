#!/usr/bin/env bash
# One-liner equivalent (CRLF-proof), to run from the repo root in Git Bash:
#   sed -i 's|^unix:   DEFINES += compiled_string=.*|&\nwin32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS|' qblade.pro
# Adds: win32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS
# (NOMINMAX/WIN32_LEAN_AND_MEAN stop windows.h from pulling rpcndr.h -> macro 'small';
#  _CRT_NONSTDC_NO_WARNINGS silences isnan/isinf/fpclassify deprecation noise)
sed -i 's/^\(unix:   DEFINES += compiled_string=.*\)\r\?$/\1\nwin32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS/' qblade.pro
grep -n "NOMINMAX" qblade.pro
