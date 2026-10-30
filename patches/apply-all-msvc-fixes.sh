#!/usr/bin/env bash
# All-in-one MSVC fixes for QBladeCE on Windows (msvc2019_64).
# Self-heals CRLF line endings (git autocrlf) before doing anything.
sed -i 's/\r$//' "$0"
set -e
cd "$(dirname "$0")/.."

# 1) FoilModule.cpp lines 1416-1432: small->smallVal, large->largeVal (C2632, rpcndr.h macro 'small')
sed -i '1416,1432{s/\bsmall\b/smallVal/g; s/\blarge\b/largeVal/g}' src/FoilModule/FoilModule.cpp

# 2) StoreAssociatedComboBox.h: include StorableObject.h, drop forward declaration (C2440)
sed -i 's|#include "StoreAssociatedComboBox_include.h"|#include "StoreAssociatedComboBox_include.h"\n#include "StorableObject.h"|' src/StoreAssociatedComboBox.h
sed -i '/^class StorableObject;$/d' src/StoreAssociatedComboBox.h

# 3) StrModel.cpp line 1576: isnan -> std::isnan (C2668 fpclassify ambiguous)
sed -i '1576s/\bisnan(/std::isnan(/' src/StructModel/StrModel.cpp

echo "--- verification ---"
grep -n "smallVal\|largeVal" src/FoilModule/FoilModule.cpp | head -6
grep -n "StorableObject.h" src/StoreAssociatedComboBox.h
grep -n "std::isnan(angle)" src/StructModel/StrModel.cpp

if grep -qn "double small \|double large " src/FoilModule/FoilModule.cpp; then
  echo "ERREUR: 'small'/'large' non renommes dans FoilModule.cpp"; exit 1
fi
echo "OK: tous les fix MSVC appliques"
