#!/usr/bin/env bash
# Master MSVC-fix script v10 for QBladeCE on Windows (msvc2019_64). Run FROM REPO ROOT:
#   bash -c "$(tr -d '\r' < patches/apply-all-msvc-fixes-v10.sh)"
# Idempotent. v9 fixes + robust IceParticle.cpp patch (python-based, CRLF-proof, replaces
# the whole block between 'void IceParticle::RandomParameterParticle' and the mt19937 line).
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

# IceParticle.cpp: replace POSIX clock block with portable version (python, CRLF-safe)
ip=src/IceThrowSimulation/IceParticle.cpp
python3 - "$ip" <<'PYEOF'
import sys, re
p = sys.argv[1]
s = open(p, encoding='utf-8', errors='surrogateescape').read()
s = s.replace('\r\n', '\n')
if '#include <chrono>' not in s:
    s = s.replace('#include <qdebug.h>',
                  '#include <qdebug.h>\n#ifdef _WIN32\n#include <chrono>\n#else\n#include <ctime>\n#endif', 1)
old = re.compile(r'    struct timespec tm;\n    clock_gettime\(CLOCK_REALTIME, &tm\);\n', re.S)
new = ('    long long seedNsec;\n'
       '#ifdef _WIN32\n'
       '    seedNsec = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now().time_since_epoch()).count();\n'
       '#else\n'
       '    struct timespec tm;\n'
       '    clock_gettime(CLOCK_REALTIME, &tm);\n'
       '    seedNsec = tm.tv_nsec;\n'
       '#endif\n')
s2, n = old.subn(new, s)
if n == 0 and 'seedNsec' not in s:
    raise SystemExit('ERREUR: bloc clock_gettime introuvable dans IceParticle.cpp')
s = s2.replace('(tm.tv_nsec%100000000000)+ParticleID', '(seedNsec%100000000000)+ParticleID')
open(p, 'w', encoding='utf-8', errors='surrogateescape', newline='').write(s)
print('IceParticle patch ok, subs=%d' % n)
PYEOF
grep -n "seedNsec\|chrono" "$ip" | head -6

echo "--- verification ---"
grep -n "smallVal\|largeVal" src/FoilModule/FoilModule.cpp | head -3
grep -n "getCurrentObjectUncasted () const {" "$h" | tail -1
grep -n "isnan(angle)" src/StructModel/StrModel.cpp
grep -c "std::isnan(double(h))" src/TwoDWidgetInterface.cpp src/QBEM/BEM.cpp src/PolarModule/PolarModule.cpp src/FoilModule/FoilModule.cpp
if grep -qn "double small \|double large " src/FoilModule/FoilModule.cpp; then echo "ERREUR small/large"; exit 1; fi
if ! grep -q "static_cast<StorableObject\*> (static_cast<void\*>" "$h"; then echo "ERREUR void* cast manquant"; exit 1; fi
if ! grep -q "seedNsec" "$ip"; then echo "ERREUR IceParticle non patche"; exit 1; fi
if grep -n "clock_gettime" "$ip" | grep -v "#else" | grep -qv "seedNsec = tm"; then :; fi
if grep -rn "std::isnan(h) || std::isnan(w)" src --include=*.cpp --include=*.h | grep -v "double(" | grep -q .; then echo "ERREUR isnan(int) restant"; exit 1; fi
echo "OK: tous les fix MSVC appliques"
