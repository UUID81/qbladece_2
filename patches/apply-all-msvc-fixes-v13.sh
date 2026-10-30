#!/usr/bin/env bash
# Master MSVC-fix script v13 for QBladeCE on Windows (msvc2019_64). Run FROM REPO ROOT:
#   bash -c "$(tr -d '\r' < patches/apply-all-msvc-fixes-v13.sh)"
# v12 fixes, with the TBEMData patch anchored on the function signature (line 82 only,
# NOT the void startSimulation at line ~146). Everything python-based, CRLF-proof, idempotent.
set -e
cd "$(pwd)"

python3 - <<'PYEOF'
import re

def read(p):
    return open(p, encoding='utf-8', errors='surrogateescape').read().replace('\r\n', '\n')
def write(p, s):
    open(p, 'w', encoding='utf-8', errors='surrogateescape', newline='').write(s)

def patch(path, subs, must=True):
    s = read(path)
    for old, new in subs:
        if old in s:
            s = s.replace(old, new)
        elif must:
            raise SystemExit('ERREUR pattern introuvable dans %s: %r' % (path, old[:70]))
    write(path, s)
    print('patched', path)

# 1) qblade.pro: NOMINMAX without LEAN_AND_MEAN (gl.h needs wingdi.h), keep _CRT_NONSTDC_NO_WARNINGS, add EIGEN_DONT_VECTORIZE _USE_MATH_DEFINES
s = read('qblade.pro')
s = s.replace('win32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS',
              'win32:  DEFINES += NOMINMAX _CRT_NONSTDC_NO_WARNINGS')
if 'NOMINMAX' not in s:
    s = re.sub(r'(unix:   DEFINES \+= compiled_string=.*)\n',
               r'\1\nwin32:  DEFINES += NOMINMAX _CRT_NONSTDC_NO_WARNINGS\n', s, count=1)
if 'EIGEN_DONT_VECTORIZE' not in s:
    s = re.sub(r'(win32:  DEFINES \+= NOMINMAX.*)\n',
               r'\1\nwin32:  DEFINES += EIGEN_DONT_VECTORIZE _USE_MATH_DEFINES\n', s, count=1)
write('qblade.pro', s); print('patched qblade.pro')

# 2) FoilModule small/large -> smallVal/largeVal
patch('src/FoilModule/FoilModule.cpp', [
    ('    double small = 1000000;\n    double large = -100000;',
     '    double smallVal = 1000000;\n    double largeVal = -100000;'),
    ('        if (pNewFoil->x[j] < small){\n            small = pNewFoil->x[j];',
     '        if (pNewFoil->x[j] < smallVal){\n            smallVal = pNewFoil->x[j];'),
    ('        if (pNewFoil->x[j] > large){\n            large = pNewFoil->x[j];',
     '        if (pNewFoil->x[j] > largeVal){\n            largeVal = pNewFoil->x[j];'),
], must=False)

# 3) StoreAssociatedComboBox.h
h = 'src/StoreAssociatedComboBox.h'
s = read(h)
if '#include "StorableObject.h"' not in s:
    s = s.replace('#include "StoreAssociatedComboBox_include.h"',
                  '#include "StoreAssociatedComboBox_include.h"\n#include "StorableObject.h"', 1)
s = re.sub(r'^class StorableObject;\n', '', s, flags=re.M)
s = re.sub(r'return currentObject\(\); \}',
           'return static_cast<StorableObject*> (static_cast<void*> (currentObject())); }', s)
s = re.sub(r'return static_cast<StorableObject\*> \(currentObject\(\)\); \}',
           'return static_cast<StorableObject*> (static_cast<void*> (currentObject())); }', s)
write(h, s); print('patched', h)

# 4) StrModel isnan
patch('src/StructModel/StrModel.cpp', [
    ('    if (isnan(angle)) angle = 0;', '    if (std::isnan(angle)) angle = 0;'),
], must=False)

# 5) isnan/isinf(int w,h) -> double()
for c in ['src/TwoDWidgetInterface.cpp', 'src/QBEM/BEM.cpp', 'src/PolarModule/PolarModule.cpp', 'src/FoilModule/FoilModule.cpp']:
    patch(c, [(
        'std::isnan(h) || std::isnan(w) || std::isinf(h) || std::isinf(w)',
        'std::isnan(double(h)) || std::isnan(double(w)) || std::isinf(double(h)) || std::isinf(double(w))'
    )], must=False)

# 6) IceParticle seeding block rewrite (anchored)
ip = 'src/IceThrowSimulation/IceParticle.cpp'
s = read(ip)
if '#include <chrono>' not in s:
    s = s.replace('#include <qdebug.h>',
                  '#include <qdebug.h>\n#ifdef _WIN32\n#include <chrono>\n#else\n#include <ctime>\n#endif', 1)
pat = re.compile(
    r'(void IceParticle::RandomParameterParticle\([^\n]*\{\n(?:[^\n]*\n)*?)(.*?)'
    r'(    // http://en\.cppreference\.com/w/cpp/numeric/random\n)', re.S)
clean = ('    long long seedNsec;\n'
         '#ifdef _WIN32\n'
         '    seedNsec = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now().time_since_epoch()).count();\n'
         '#else\n'
         '    struct timespec tm;\n'
         '    clock_gettime(CLOCK_REALTIME, &tm);\n'
         '    seedNsec = tm.tv_nsec;\n'
         '#endif\n\n')
s, n = pat.subn(lambda m: m.group(1) + clean + m.group(3), s, count=1)
if n == 0:
    raise SystemExit('ERREUR RandomParameterParticle introuvable')
s = s.replace('(tm.tv_nsec%100000000000)+ParticleID', '(seedNsec%100000000000)+ParticleID')
write(ip, s); print('patched', ip)

# 7) Blade.cpp VLA -> fixed size / QVector
patch('src/QBEM/Blade.cpp', [
    ('#include <QDebug>\n', '#include <QDebug>\n#include <QVector>\n'),
    ('    double height[m_NPanel];\n    double length[m_NPanel];',
     '    double height[MAXBLADESTATIONS+1];\n    double length[MAXBLADESTATIONS+1];'),
    ('    const int stations = bladeDisc.TPos.size();\n    double length[stations];',
     '    const int stations = bladeDisc.TPos.size();\n    QVector<double> length(stations);'),
    ('    double fractions[m_NPanel];', '    double fractions[MAXBLADESTATIONS+1];'),
], must=False)

# 8) CBEMData::newCurve missing return (anchored on the commented return + closing brace)
patch('src/QBEM/CBEMData.cpp', [(
    "//\treturn curve;\n}\n",
    "//\treturn curve;\n    return NULL;\n}\n"
)], must=False)

# 9) TBEMData::accessParameter missing return - anchored on the FULL signature (not the void startSimulation)
patch('src/QBEM/TBEMData.cpp', [(
    'QVariant TBEMData::accessParameter(Parameter::TBEMData::Key key, QVariant value) {\n\t// TODO\n}',
    'QVariant TBEMData::accessParameter(Parameter::TBEMData::Key key, QVariant value) {\n\t// TODO\n    return QVariant();\n}'
)], must=False)
# remove any wrongly-added return inside void startSimulation (from a previous bad run)
s = read('src/QBEM/TBEMData.cpp')
s = s.replace('void TBEMData::startSimulation() {\n\t// TODO\n    return QVariant();\n}',
              'void TBEMData::startSimulation() {\n\t// TODO\n}')
write('src/QBEM/TBEMData.cpp', s)
PYEOF

echo "--- verification ---"
grep -n "NOMINMAX\|EIGEN_DONT_VECTORIZE" qblade.pro
grep -c "smallVal" src/FoilModule/FoilModule.cpp
grep -n "getCurrentObjectUncasted () const {" src/StoreAssociatedComboBox.h | tail -1
grep -n "isnan(angle)" src/StructModel/StrModel.cpp
grep -c "std::isnan(double(h))" src/TwoDWidgetInterface.cpp src/QBEM/BEM.cpp src/PolarModule/PolarModule.cpp src/FoilModule/FoilModule.cpp
grep -c "seedNsec" src/IceThrowSimulation/IceParticle.cpp
grep -n "MAXBLADESTATIONS+1\]\|QVector<double> length" src/QBEM/Blade.cpp
grep -n "return NULL;" src/QBEM/CBEMData.cpp | tail -1
grep -n "return QVariant();" src/QBEM/TBEMData.cpp
if grep -q "WIN32_LEAN_AND_MEAN" qblade.pro; then echo "ERREUR LEAN_AND_MEAN present"; exit 1; fi
if grep -rn "double length\[stations\]\|double height\[m_NPanel\]\|double fractions\[m_NPanel\]" src/QBEM/Blade.cpp | grep -q .; then echo "ERREUR VLA restant"; exit 1; fi
if grep -q "return QVariant();" <(sed -n '/void TBEMData::startSimulation/,/^}/p' src/QBEM/TBEMData.cpp); then echo "ERREUR return dans startSimulation (void)"; exit 1; fi
echo "OK: tous les fix MSVC appliques"
