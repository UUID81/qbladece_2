#!/usr/bin/env bash
# Master MSVC-fix script v4 for QBladeCE on Windows (msvc2019_64). Run FROM REPO ROOT:
#   bash -c "$(tr -d '\r' < patches/apply-all-msvc-fixes-v4.sh)"
# Idempotent (safe to run several times).
#  1) qblade.pro win32 DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS
#     (stops windows.h/rpcndr.h macros small/large; silences fpclassify/isnan noise)
#  2) qblade.pro win32 DEFINES += EIGEN_DONT_VECTORIZE _USE_MATH_DEFINES
#     (Eigen: avoid MSVC fpclassify ambiguity on vectorized paths; expose M_PI)
#  3) src/FoilModule/FoilModule.cpp lines 1416-1432: small->smallVal, large->largeVal (C2632)
#  4) src/StoreAssociatedComboBox.h: #include "StorableObject.h" replaces forward decl (C2440)
#  5) src/StructModel/StrModel.cpp line 1576: isnan -> std::isnan (C2668), idempotent
set -e
cd "$(pwd)"

f=qblade.pro
if ! grep -q "NOMINMAX" "$f"; then
  sed -i "s/^\(unix:   DEFINES += compiled_string=.*\)\r\?$/\1\nwin32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS/" "$f"
fi
if ! grep -q "EIGEN_DONT_VECTORIZE" "$f"; then
  sed -i "s/^\(win32:  DEFINES += NOMINMAX.*\)\r\?$/\1\nwin32:  DEFINES += EIGEN_DONT_VECTORIZE _USE_MATH_DEFINES/" "$f"
fi
grep -n "NOMINMAX\|EIGEN_DONT_VECTORIZE" "$f"

sed -i '1416,1432{s/\bsmall\b/smallVal/g; s/\blarge\b/largeVal/g}' src/FoilModule/FoilModule.cpp

if ! grep -q '#include "StorableObject.h"' src/StoreAssociatedComboBox.h; then
  sed -i 's|#include "StoreAssociatedComboBox_include.h"|#include "StoreAssociatedComboBox_include.h"\n#include "StorableObject.h"|' src/StoreAssociatedComboBox.h
  sed -i '/^class StorableObject;$/d' src/StoreAssociatedComboBox.h
fi

if grep -q '[^:]isnan(angle)' src/StructModel/StrModel.cpp; then
  sed -i '1576s/\bisnan(angle)/std::isnan(angle)/' src/StructModel/StrModel.cpp
fi

echo "--- verification ---"
grep -n "smallVal\|largeVal" src/FoilModule/FoilModule.cpp | head -6
grep -n "StorableObject.h" src/StoreAssociatedComboBox.h
grep -n "isnan(angle)" src/StructModel/StrModel.cpp
if grep -qn "double small \|double large " src/FoilModule/FoilModule.cpp; then
  echo "ERREUR: 'small'/'large' non renommes dans FoilModule.cpp"; exit 1
fi
echo "OK: tous les fix MSVC appliques"
