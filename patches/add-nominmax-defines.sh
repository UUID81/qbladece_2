#!/usr/bin/env bash
# Add MSVC-safe DEFINES to qblade.pro (line after the unix compiled_string line):
#   win32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS
# NOMINMAX/WIN32_LEAN_AND_MEAN keep windows.h from pulling rpcndr.h (macro 'small')
# _CRT_NONSTDC_NO_WARNINGS silences the deprecation noise for isnan/isinf/fpclassify
set -e
cd "$(dirname "$0")/.."
sed -i 's/\r$//' "$0"
f=qblade.pro
if grep -q "NOMINMAX" "$f"; then echo "deja present"; exit 0; fi
sed -i 's|^unix:   DEFINES += compiled_string=.*|&\nwin32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS|' "$f"
grep -n "NOMINMAX" "$f"
echo "OK: DEFINES ajoutes a qblade.pro"
