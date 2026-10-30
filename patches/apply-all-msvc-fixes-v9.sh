#!/usr/bin/env bash
# Master MSVC-fix script v9 for QBladeCE on Windows (msvc2019_64). Run FROM REPO ROOT:
#   bash -c "$(tr -d '\r' < patches/apply-all-msvc-fixes-v9.sh)"
# Idempotent. All v8 fixes PLUS:
#  8) src/IceThrowSimulation/IceParticle.cpp: clock_gettime/CLOCK_REALTIME (POSIX, C2065/C3861 on MSVC)
#     -> on _WIN32 use std::chrono::high_resolution_clock, else keep clock_gettime
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

# IceParticle.cpp: POSIX clock_gettime -> chrono on Windows
ip=src/IceThrowSimulation/IceParticle.cpp
if grep -q "clock_gettime" "$ip"; then
  sed -i 's|#include <qdebug.h>|#include <qdebug.h>\n#ifdef _WIN32\n#include <chrono>\n#else\n#include <ctime>\n#endif|' "$ip"
  sed -i 's|    struct timespec tm;\r$|    long long seedNsec;\n#ifdef _WIN32\n    seedNsec = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now().time_since_epoch()).count();\n#else\n    struct timespec tm;|' "$ip"
  sed -i 's|    clock_gettime(CLOCK_REALTIME, &tm);\r$|    clock_gettime(CLOCK_REALTIME, \&tm);\n    seedNsec = tm.tv_nsec;\n#endif|' "$ip"
  sed -i 's|(tm.tv_nsec%100000000000)+ParticleID|(seedNsec%100000000000)+ParticleID|' "$ip"
fi
grep -n "seedNsec\|clock_gettime\|chrono" "$ip" | head -8

echo "--- verification ---"
grep -n "smallVal\|largeVal" src/FoilModule/FoilModule.cpp | head -3
grep -n "getCurrentObjectUncasted () const {" "$h" | tail -1
grep -n "isnan(angle)" src/StructModel/StrModel.cpp
grep -c "std::isnan(double(h))" src/TwoDWidgetInterface.cpp src/QBEM/BEM.cpp src/PolarModule/PolarModule.cpp src/FoilModule/FoilModule.cpp
if grep -qn "double small \|double large " src/FoilModule/FoilModule.cpp; then echo "ERREUR small/large"; exit 1; fi
if ! grep -q "static_cast<StorableObject\*> (static_cast<void\*>" "$h"; then echo "ERREUR void* cast manquant"; exit 1; fi
if grep -q "clock_gettime" "$ip" && ! grep -q "seedNsec" "$ip"; then echo "ERREUR IceParticle non patche"; exit 1; fi
if grep -rn "std::isnan(h) || std::isnan(w)" src --include=*.cpp --include=*.h | grep -v "double(" | grep -q .; then echo "ERREUR isnan(int) restant"; exit 1; fi
echo "OK: tous les fix MSVC appliques"
