#!/usr/bin/env bash
# Master MSVC-fix script for QBladeCE on Windows (msvc2019_64).
# Applies, from the repo root:
#  1) qblade.pro: win32 DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS
#     (stops windows.h/rpcndr.h macros 'small'/'large' and silences fpclassify/isnan noise)
#  2) src/FoilModule/FoilModule.cpp lines 1416-1432: small->smallVal, large->largeVal (C2632)
#  3) src/StoreAssociatedComboBox.h: #include "StorableObject.h" replaces forward decl (C2440)
#  4) src/StructModel/StrModel.cpp line 1576: isnan -> std::isnan (C2668)
# CRLF-proof: run as   bash -c "$(tr -d '\r' < patches/apply-all-msvc-fixes-v2.sh)"
set -e
cd "$(dirname "$0")" >/dev/null 2>&1 || true
cd "$(pwd)"

f=qblade.pro
if ! grep -q "NOMINMAX" "$f"; then
  sed -i "s/^\(unix:   DEFINES += compiled_string=.*\)\r\?$/\1\nwin32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS/" "$f"
fi
grep -n "NOMINMAX" "$f"

sed -i '1416,1432{s/\bsmall\b/smallVal/g; s/\blarge\b/largeVal/g}' src/FoilModule/FoilModule.cpp

if ! grep -q '#include "StorableObject.h"' src/StoreAssociatedComboBox.h; then
  sed -i 's|#include "StoreAssociatedComboBox_include.h"|#include "StoreAssociatedComboBox_include.h"\n#include "StorableObject.h"|' src/StoreAssociatedComboBox.h
  sed -i '/^class StorableObject;$/d' src/StoreAssociatedComboBox.h
fi

sed -i '1576s/\bisnan(/std::isnan(/' src/StructModel/StrModel.cpp

echo "--- verification ---"
grep -n "smallVal\|largeVal" src/FoilModule/FoilModule.cpp | head -6
grep -n "StorableObject.h" src/StoreAssociatedComboBox.h
grep -n "std::isnan(angle)" src/StructModel/StrModel.cpp
if grep -qn "double small \|double large " src/FoilModule/FoilModule.cpp; then
  echo "ERREUR: 'small'/'large' non renommes dans FoilModule.cpp"; exit 1
fi
echo "OK: tous les fix MSVC appliques"
