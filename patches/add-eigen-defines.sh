#!/usr/bin/env bash
# Adds two more win32 DEFINES to qblade.pro (right after the NOMINMAX line if present,
# otherwise after the unix compiled_string line):
#   win32:  DEFINES += EIGEN_DONT_VECTORIZE EIGEN_DISABLE_UNALIGNED_ARRAY_ASSERT _USE_MATH_DEFINES
# EIGEN_DONT_VECTORIZE: avoids Eigen calling fpclassify/isnan on vectorized paths under MSVC
# _USE_MATH_DEFINES: exposes M_PI etc. from <math.h> on MSVC
# CRLF-proof invocation from repo root:
#   bash -c "$(tr -d '\r' < patches/add-eigen-defines.sh)"
f=qblade.pro
if grep -q "EIGEN_DONT_VECTORIZE" "$f"; then echo "deja present"; exit 0; fi
if grep -q "NOMINMAX" "$f"; then
  sed -i "s/^\(win32:  DEFINES += NOMINMAX.*\)\r\?$/\1\nwin32:  DEFINES += EIGEN_DONT_VECTORIZE _USE_MATH_DEFINES/" "$f"
else
  sed -i "s/^\(unix:   DEFINES += compiled_string=.*\)\r\?$/\1\nwin32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS EIGEN_DONT_VECTORIZE _USE_MATH_DEFINES/" "$f"
fi
grep -n "EIGEN_DONT_VECTORIZE\|NOMINMAX" "$f"
echo "OK"
