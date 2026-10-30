#!/usr/bin/env bash
# Master MSVC-fix script v6 for QBladeCE on Windows (msvc2019_64). Run FROM REPO ROOT:
#   bash -c "$(tr -d '\r' < patches/apply-all-msvc-fixes-v6.sh)"
# Idempotent (safe to run several times). Fixes:
#  1) qblade.pro win32 DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS
#  2) qblade.pro win32 DEFINES += EIGEN_DONT_VECTORIZE _USE_MATH_DEFINES
#  3) src/FoilModule/FoilModule.cpp lines 1416-1432: small->smallVal, large->largeVal (C2632)
#  4) src/StoreAssociatedComboBox.h: include StorableObject.h AND delete the leftover
#     'class StorableObject;' forward declaration (CRLF-safe pattern) - C2440
#  5) src/StructModel/StrModel.cpp line 1576: isnan -> std::isnan (C2668)
#  6) C2668 fpclassify root cause: std::isnan/isinf on int w,h -> double(h)/double(w)
#     in TwoDWidgetInterface.cpp, BEM.cpp, PolarModule.cpp, FoilModule.cpp
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

h=src/StoreAssociatedComboBox.h
if ! grep -q '#include "StorableObject.h"' "$h"; then
  sed -i 's|#include "StoreAssociatedComboBox_include.h"|#include "StoreAssociatedComboBox_include.h"\n#include "StorableObject.h"|' "$h"
fi
sed -i '/^class StorableObject;\r\?$/d' "$h"
grep -n "StorableObject" "$h" | head -3

if grep -q '[^:]isnan(angle)' src/StructModel/StrModel.cpp; then
  sed -i '1576s/\bisnan(angle)/std::isnan(angle)/' src/StructModel/StrModel.cpp
fi

for c in src/TwoDWidgetInterface.cpp src/QBEM/BEM.cpp src/PolarModule/PolarModule.cpp src/FoilModule/FoilModule.cpp; do
  sed -i 's/std::isnan(h) || std::isnan(w) || std::isinf(h) || std::isinf(w)/std::isnan(double(h)) || std::isnan(double(w)) || std::isinf(double(h)) || std::isinf(double(w))/g' "$c"
done

echo "--- verification ---"
grep -n "smallVal\|largeVal" src/FoilModule/FoilModule.cpp | head -6
grep -n "StorableObject" src/StoreAssociatedComboBox.h
grep -n "isnan(angle)" src/StructModel/StrModel.cpp
grep -c "std::isnan(double(h))" src/TwoDWidgetInterface.cpp src/QBEM/BEM.cpp src/PolarModule/PolarModule.cpp src/FoilModule/FoilModule.cpp
if grep -qn "double small \|double large " src/FoilModule/FoilModule.cpp; then
  echo "ERREUR: 'small'/'large' non renommes dans FoilModule.cpp"; exit 1
fi
if grep -qn "^class StorableObject;" src/StoreAssociatedComboBox.h; then
  echo "ERREUR: forward declaration 'class StorableObject;' encore present"; exit 1
fi
if grep -rn "std::isnan(h) || std::isnan(w)" src --include=*.cpp --include=*.h | grep -v "double(" | grep -q .; then
  echo "ERREUR: il reste des std::isnan(int) non castes"; exit 1
fi
echo "OK: tous les fix MSVC appliques"
