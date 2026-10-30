#!/usr/bin/env bash
# Master MSVC-fix script v8 for QBladeCE on Windows (msvc2019_64). Run FROM REPO ROOT:
#   bash -c "$(tr -d '\r' < patches/apply-all-msvc-fixes-v8.sh)"
# Idempotent. All previous fixes PLUS:
#  7b) src/StoreAssociatedComboBox.h line 200: MSVC rejects even static_cast<T*>->StorableObject*
#      on incomplete T. Fix: go through void*:
#      return static_cast<StorableObject*> (static_cast<void*> (currentObject()));
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
sed -i 's|return currentObject(); }|return static_cast<StorableObject*> (static_cast<void*> (currentObject())); }|' "$h"
sed -i 's|return static_cast<StorableObject\*> (currentObject()); }|return static_cast<StorableObject*> (static_cast<void*> (currentObject())); }|' "$h"
grep -n "getCurrentObjectUncasted () const {" "$h" | tail -1

if grep -q '[^:]isnan(angle)' src/StructModel/StrModel.cpp; then
  sed -i '1576s/\bisnan(angle)/std::isnan(angle)/' src/StructModel/StrModel.cpp
fi

for c in src/TwoDWidgetInterface.cpp src/QBEM/BEM.cpp src/PolarModule/PolarModule.cpp src/FoilModule/FoilModule.cpp; do
  sed -i 's/std::isnan(h) || std::isnan(w) || std::isinf(h) || std::isinf(w)/std::isnan(double(h)) || std::isnan(double(w)) || std::isinf(double(h)) || std::isinf(double(w))/g' "$c"
done

echo "--- verification ---"
grep -n "smallVal\|largeVal" src/FoilModule/FoilModule.cpp | head -6
grep -n "StorableObject" src/StoreAssociatedComboBox.h | head -4
grep -n "isnan(angle)" src/StructModel/StrModel.cpp
grep -c "std::isnan(double(h))" src/TwoDWidgetInterface.cpp src/QBEM/BEM.cpp src/PolarModule/PolarModule.cpp src/FoilModule/FoilModule.cpp
if grep -qn "double small \|double large " src/FoilModule/FoilModule.cpp; then echo "ERREUR small/large"; exit 1; fi
if grep -qn "^class StorableObject;" src/StoreAssociatedComboBox.h; then echo "ERREUR forward decl"; exit 1; fi
if ! grep -q "static_cast<StorableObject\*> (static_cast<void\*>" src/StoreAssociatedComboBox.h; then echo "ERREUR void* cast manquant"; exit 1; fi
if grep -rn "std::isnan(h) || std::isnan(w)" src --include=*.cpp --include=*.h | grep -v "double(" | grep -q .; then echo "ERREUR isnan(int) restant"; exit 1; fi
echo "OK: tous les fix MSVC appliques"
