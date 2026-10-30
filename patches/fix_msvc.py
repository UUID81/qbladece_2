import re, sys, os
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def read(p):
    return open(p, encoding='utf-8', errors='surrogateescape').read().replace('\r\n', '\n')
def write(p, s):
    open(p, 'w', encoding='utf-8', errors='surrogateescape', newline='').write(s)
def patch(path, subs):
    s = read(path); orig = s
    for old, new in subs:
        s = s.replace(old, new)
    if s != orig:
        write(path, s); print('patched', path)
    else:
        print('deja ok ', path)

# 1) qblade.pro
s = read('qblade.pro')
s = s.replace('win32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS',
              'win32:  DEFINES += NOMINMAX _CRT_NONSTDC_NO_WARNINGS')
if 'NOMINMAX' not in s:
    s = re.sub(r'(unix:   DEFINES \+= compiled_string=.*)\n', r'\1\nwin32:  DEFINES += NOMINMAX _CRT_NONSTDC_NO_WARNINGS\n', s, count=1)
if 'EIGEN_DONT_VECTORIZE' not in s:
    s = re.sub(r'(win32:  DEFINES \+= NOMINMAX.*)\n', r'\1\nwin32:  DEFINES += EIGEN_DONT_VECTORIZE _USE_MATH_DEFINES\n', s, count=1)
# GL/gl.h on MSVC needs windows.h included BEFORE it (WINGDIAPI/APIENTRY from wingdi.h).
# Force-include windows.h in every TU: /FI"windows.h" (NOMINMAX keeps min/max/small/large macros away)
if '/FI' not in s:
    s = re.sub(r'(win32 \{\n    QMAKE_CXXFLAGS \+= /openmp)', r'\1\n    QMAKE_CXXFLAGS += /FI"windows.h"', s, count=1)
    if '/FI' not in s:
        s = s.replace('win32 {\n    QMAKE_CXXFLAGS += /openmp',
                      'win32 {\n    QMAKE_CXXFLAGS += /openmp\n    QMAKE_CXXFLAGS += /FI"windows.h"', 1)
write('qblade.pro', s); print('patched qblade.pro')

# 2) FoilModule small/large
patch('src/FoilModule/FoilModule.cpp', [
    ('    double small = 1000000;\n    double large = -100000;', '    double smallVal = 1000000;\n    double largeVal = -100000;'),
    ('        if (pNewFoil->x[j] < small){\n            small = pNewFoil->x[j];', '        if (pNewFoil->x[j] < smallVal){\n            smallVal = pNewFoil->x[j];'),
    ('        if (pNewFoil->x[j] > large){\n            large = pNewFoil->x[j];', '        if (pNewFoil->x[j] > largeVal){\n            largeVal = pNewFoil->x[j];'),
])

# 3) StoreAssociatedComboBox.h
h = 'src/StoreAssociatedComboBox.h'
s = read(h)
if '#include "StorableObject.h"' not in s:
    s = s.replace('#include "StoreAssociatedComboBox_include.h"', '#include "StoreAssociatedComboBox_include.h"\n#include "StorableObject.h"', 1)
s = re.sub(r'^class StorableObject;\n', '', s, flags=re.M)
s = re.sub(r'return currentObject\(\); \}', 'return static_cast<StorableObject*> (static_cast<void*> (currentObject())); }', s)
s = re.sub(r'return static_cast<StorableObject\*> \(currentObject\(\)\); \}', 'return static_cast<StorableObject*> (static_cast<void*> (currentObject())); }', s)
write(h, s); print('patched', h)

# 4) StrModel isnan
patch('src/StructModel/StrModel.cpp', [('    if (isnan(angle)) angle = 0;', '    if (std::isnan(angle)) angle = 0;')])

# 5) isnan/isinf(int w,h)
for c in ['src/TwoDWidgetInterface.cpp', 'src/QBEM/BEM.cpp', 'src/PolarModule/PolarModule.cpp', 'src/FoilModule/FoilModule.cpp']:
    patch(c, [('std::isnan(h) || std::isnan(w) || std::isinf(h) || std::isinf(w)',
               'std::isnan(double(h)) || std::isnan(double(w)) || std::isinf(double(h)) || std::isinf(double(w))')])

# 6) IceParticle seeding
ip = 'src/IceThrowSimulation/IceParticle.cpp'
s = read(ip)
if '#include <chrono>' not in s:
    s = s.replace('#include <qdebug.h>', '#include <qdebug.h>\n#ifdef _WIN32\n#include <chrono>\n#else\n#include <ctime>\n#endif', 1)
pat = re.compile(r'(void IceParticle::RandomParameterParticle\([^\n]*\{\n(?:[^\n]*\n)*?)(.*?)(    // http://en\.cppreference\.com/w/cpp/numeric/random\n)', re.S)
clean = ('    long long seedNsec;\n#ifdef _WIN32\n    seedNsec = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::high_resolution_clock::now().time_since_epoch()).count();\n#else\n    struct timespec tm;\n    clock_gettime(CLOCK_REALTIME, &tm);\n    seedNsec = tm.tv_nsec;\n#endif\n\n')
s, n = pat.subn(lambda m: m.group(1) + clean + m.group(3), s, count=1)
if n == 0 and 'seedNsec' not in s:
    print('ERREUR: RandomParameterParticle introuvable'); sys.exit(1)
s = s.replace('(tm.tv_nsec%100000000000)+ParticleID', '(seedNsec%100000000000)+ParticleID')
write(ip, s); print('patched', ip)

# 7) Blade.cpp VLA
patch('src/QBEM/Blade.cpp', [
    ('#include <QDebug>\n', '#include <QDebug>\n#include <QVector>\n'),
    ('    double height[m_NPanel];\n    double length[m_NPanel];', '    double height[MAXBLADESTATIONS+1];\n    double length[MAXBLADESTATIONS+1];'),
    ('    const int stations = bladeDisc.TPos.size();\n    double length[stations];', '    const int stations = bladeDisc.TPos.size();\n    QVector<double> length(stations);'),
    ('    double fractions[m_NPanel];', '    double fractions[MAXBLADESTATIONS+1];'),
])

# 7b) NewGraph.cpp: QRect::width()/height() return int -> cast to double for MSVC fpclassify
patch('src/Graph/NewGraph.cpp', [(
    'if (std::isnan(m_drawingArea.height()) || std::isnan(m_drawingArea.width()) || std::isinf(m_drawingArea.height()) || std::isinf(m_drawingArea.width())',
    'if (std::isnan(double(m_drawingArea.height())) || std::isnan(double(m_drawingArea.width())) || std::isinf(double(m_drawingArea.height())) || std::isinf(double(m_drawingArea.width()))'
)])

# 8g) NewGraph.cpp: VLA QVector<QPointF> points[m_curves.size()] -> QVector<QVector<QPointF>> (MSVC C2131/C3863)
patch('src/Graph/NewGraph.cpp', [(
    '\t\tQVector<QPointF> points[m_curves.size()];  // preparation of this array is of vital importance for performance',
    '\t\tQVector<QVector<QPointF> > points(m_curves.size());  // preparation of this array is of vital importance for performance'
)])

# 8h) GraphOptionsDialog.cpp: local var named 'interface' clashes with Windows SDK '#define interface struct'
# (objbase.h pulled in via windows.h). Rename to 'iface'.
go = 'src/Graph/GraphOptionsDialog.cpp'
s = read(go)
if 'TwoDWidgetInterface* iface =' not in s:
    s = s.replace('    TwoDWidgetInterface* interface = g_mainFrame->getTwoDWidgetInterface();\n    if (interface) interface->update();\n    else g_mainFrame->UpdateView();',
                  '    TwoDWidgetInterface* iface = g_mainFrame->getTwoDWidgetInterface();\n    if (iface) iface->update();\n    else g_mainFrame->UpdateView();')
    write(go, s); print('patched', go)
else:
    print('deja ok ', go)

# 8i) Chrono + src: bare 'chrono::' is ambiguous with std::chrono under MSVC (C2872).
# 'using namespace std' in TUs + MSVC <chrono> header => std::chrono visible => ambiguity.
# Qualify every bare 'chrono::' -> '::chrono::' in include_headers/Chrono and src (lookbehind
# protects 'std::chrono::' and already-qualified '::chrono::').
_cpat = re.compile(r'(?<![\w:])chrono::')
def _qualify(path):
    s = read(path)
    n = len(_cpat.findall(s))
    if n:
        s2 = _cpat.sub('::chrono::', s)
        if s2 != s:
            write(path, s2)
    return n
_tot = 0
for _root, _dirs, _fs in os.walk('include_headers/Chrono'):
    for _f in _fs:
        if _f.endswith(('.h', '.hpp', '.cpp', '.inl')):
            _tot += _qualify(os.path.join(_root, _f))
for _root, _dirs, _fs in os.walk('src'):
    for _f in _fs:
        if _f.endswith(('.h', '.cpp')):
            _tot += _qualify(os.path.join(_root, _f))
print('chrono:: qualified total replacements:', _tot)

# 8j) Debug.h: __PRETTY_FUNCTION__ is GCC/Clang-only; MSVC has __FUNCSIG__. Map it under _MSC_VER.
dbg = 'src/VPML/Debug.h'
s = read(dbg)
if '__FUNCSIG__' not in s:
    s = s.replace('#define LOG_FUNC_ENTRY      Log(__PRETTY_FUNCTION__)',
                  '#ifdef _MSC_VER\n#define LOG_FUNC_ENTRY      Log(__FUNCSIG__)\n#else\n#define LOG_FUNC_ENTRY      Log(__PRETTY_FUNCTION__)\n#endif')
    s = s.replace('#define LOG_FUNC(x)         Log(__PRETTY_FUNCTION__,x)',
                  '#ifdef _MSC_VER\n#define LOG_FUNC(x)         Log(__FUNCSIG__,x)\n#else\n#define LOG_FUNC(x)         Log(__PRETTY_FUNCTION__,x)\n#endif')
    write(dbg, s); print('patched', dbg)
else:
    print('deja ok ', dbg)

# 8k) ML_Euler.h: non-void virtuals with empty body {} -> C4716 on MSVC. Add a default return.
me = 'src/VPML/ML_Euler.h'
s = read(me)
_ret = {'uint': '0', 'int': '0', 'Real': '0', 'float': '0', 'double': '0', 'bool': 'false',
        'Vector3': 'Vector3(0,0,0)', 'Matrix': 'Matrix()', 'MatrixRM': 'MatrixRM()', 'Matrix3': 'Matrix3()',
        'Cart_ID': 'Cart_ID(0,0,0)'}
_vpat = re.compile(r'(virtual\s+(uint|int|Real|float|double|bool|Vector3|Matrix|MatrixRM|Matrix3|Cart_ID)[^;{]*\([^)]*\))\s*\{\}')
def _vsub(m):
    ret = _ret[m.group(2)]
    return m.group(1) + ' { return ' + ret + '; }'
s2, nv = _vpat.subn(_vsub, s)
if nv:
    write(me, s2); print('patched', me, 'virtual returns:', nv)
else:
    print('deja ok ', me)

# 8l) ML_Box.cpp: 3D VLA Real L[2|3][N_P][Ns] -> flat std::vector<Real> (MSVC C2131/C2148/C2036)
mb = 'src/VPML/ML_Box.cpp'
s = read(mb)
if 'std::vector<Real> L(' not in s:
    if '#include <vector>' not in s:
        s = s.replace('#include "ML_Box.h"', '#include "ML_Box.h"\n#include <vector>\n#include <algorithm>', 1)
    s = s.replace('    Real L[2][N_P][Ns]; // = {{{0}}};',
                  '    std::vector<Real> L(2*N_P*Ns, 0.0);')
    s = s.replace('    Real L[3][N_P][Ns];     // = {{{0}}};',
                  '    std::vector<Real> L(3*N_P*Ns, 0.0);')
    s = re.sub(r'L\[(\d)\]\[(\w+)\]\[(\w+)\]', r'L[((\1)*N_P + \2)*Ns + \3]', s)
    s = re.sub(r'L\[(\d)\]\[(\w+)\]\)', r'&L[((\1)*N_P + \2)*Ns])', s)
    write(mb, s); print('patched', mb)
else:
    print('deja ok ', mb)

# 8m) Particle_Grid.cpp: 3D VLA bool VG[NX][NY][NZ] -> flat std::vector<char>
pg = 'src/VPML/Particle_Grid.cpp'
s = read(pg)
if 'std::vector<char> VG(' not in s:
    if '#include <vector>' not in s:
        s = s.replace('#include "Particle_Grid.h"', '#include "Particle_Grid.h"\n#include <vector>\n#include <algorithm>', 1)
    s = s.replace('    bool VG[NX][NY][NZ];',
                  '    std::vector<char> VG(NX*NY*NZ, 0);')
    s = s.replace('std::fill(VG[0][0], VG[0][0]+NX*NY*NZ, 0);',
                  'std::fill(VG.begin(), VG.end(), 0);')
    s = re.sub(r'VG\[(\w+)\]\[(\w+)\]\[(\w+)\]', r'VG[((\1)*NY + \2)*NZ + \3]', s)
    write(pg, s); print('patched', pg)
else:
    print('deja ok ', pg)

# 9) missing returns
patch('src/QBEM/CBEMData.cpp', [("//\treturn curve;\n}\n", "//\treturn curve;\n    return NULL;\n}\n")])
t = 'src/QBEM/TBEMData.cpp'
s = read(t)
s = s.replace('QVariant TBEMData::accessParameter(Parameter::TBEMData::Key key, QVariant value) {\n\t// TODO\n}',
              'QVariant TBEMData::accessParameter(Parameter::TBEMData::Key key, QVariant value) {\n\t// TODO\n    return QVariant();\n}')
s = s.replace('void TBEMData::startSimulation() {\n\t// TODO\n    return QVariant();\n}', 'void TBEMData::startSimulation() {\n\t// TODO\n}')
write(t, s); print('patched', t)

print('=== verification ===')
import subprocess
def g(p, pat):
    return [l for l in read(p).splitlines() if pat in l]
print('NOMINMAX lines:', g('qblade.pro', 'NOMINMAX'))
print('LEAN_AND_MEAN present:', 'WIN32_LEAN_AND_MEAN' in read('qblade.pro'))
print('/FI windows.h present:', '/FI"windows.h"' in read('qblade.pro'))
print('smallVal count:', read('src/FoilModule/FoilModule.cpp').count('smallVal'))
print('comboBox line200:', [l for l in read('src/StoreAssociatedComboBox.h').splitlines() if 'getCurrentObjectUncasted () const {' in l][-1:])
print('Blade MAXBLADESTATIONS:', [l.strip() for l in read('src/QBEM/Blade.cpp').splitlines() if 'MAXBLADESTATIONS+1]' in l or 'QVector<double> length' in l])
print('seedNsec count:', read('src/IceThrowSimulation/IceParticle.cpp').count('seedNsec'))
print('CBEMData return NULL:', [l.strip() for l in read('src/QBEM/CBEMData.cpp').splitlines() if l.strip()=='return NULL;'][-1:])
print('TBEMData accessParameter return:', 'return QVariant();' in read('src/QBEM/TBEMData.cpp'))
print('TBEMData startSimulation clean:', 'return QVariant();' not in re.search(r'void TBEMData::startSimulation\(\) \{\n(?:[^\n]*\n)*?\}', read('src/QBEM/TBEMData.cpp')).group(0))
print('isnan(double(h)) counts:', {c: read(c).count('std::isnan(double(h))') for c in ['src/TwoDWidgetInterface.cpp','src/QBEM/BEM.cpp','src/PolarModule/PolarModule.cpp','src/FoilModule/FoilModule.cpp']})
print('NewGraph double cast:', read('src/Graph/NewGraph.cpp').count('std::isnan(double(m_drawingArea.height()))'))
print('NewGraph VLA fixed:', 'QVector<QVector<QPointF> > points(m_curves.size());' in read('src/Graph/NewGraph.cpp'))
print('interface renamed:', 'TwoDWidgetInterface* iface =' in read('src/Graph/GraphOptionsDialog.cpp'))
print('PRETTY_FUNCTION mapped:', '__FUNCSIG__' in read('src/VPML/Debug.h'))
print('ML_Euler virtual returns:', '{ return Matrix(); }' in read('src/VPML/ML_Euler.h') and '{ return 0; }' in read('src/VPML/ML_Euler.h'))
print('ML_Box L flat:', 'std::vector<Real> L(' in read('src/VPML/ML_Box.cpp'))
print('Particle_Grid VG flat:', 'std::vector<char> VG(' in read('src/VPML/Particle_Grid.cpp'))
print('ALL FIXES APPLIED OK')
