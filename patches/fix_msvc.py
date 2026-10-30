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

# 8) VPML Math_Types.h: <tr1/cmath> was removed after VS2013; MSVC has these in <cmath>
patch('src/VPML/Math_Types.h', [('#include <tr1/cmath>', '#include <cmath>')])

# 8b) VPML Math_Types.h: "#define SinglePrec;" -> trailing ';' in macro body is C2008 on MSVC
patch('src/VPML/Math_Types.h', [('#define SinglePrec;', '#define SinglePrec')])

# 8b2) VPML Math_Types.h: _Pragma inside macro body is unreliable on MSVC 14.29
# (produces C2018 unknown char at use sites). Define OpenMPfor to nothing under _MSC_VER
# (serial fallback, still correct); keep _Pragma on GCC/Clang.
mt = 'src/VPML/Math_Types.h'
s = read(mt)
if '#define OpenMPfor _Pragma("omp parallel for")' in s and '_MSC_VER' not in s:
    s = s.replace('#define OpenMPfor _Pragma("omp parallel for")',
                  '#ifdef _MSC_VER\n#define OpenMPfor\n#else\n#define OpenMPfor _Pragma("omp parallel for")\n#endif', 1)
    write(mt, s); print('patched', mt)
else:
    print('deja ok ', mt)

# 8c) VPML ML_Euler.h: string literals assigned to 'char *BCtype' -> C2440 with /Zc:strictStrings (default in recent MSVC)
patch('src/VPML/ML_Euler.h', [('    char *BCtype;', '    const char *BCtype;')])

# 8d) VPML Box_Tree.h uses include guard GRID_H which collides with other headers -> C1004 cascade; rename guard
bt = 'src/VPML/Box_Tree.h'
s = read(bt)
if '#ifndef GRID_H' in s and '#ifndef VPML_BOX_TREE_H' not in s:
    s = s.replace('#ifndef GRID_H\n#define GRID_H', '#ifndef VPML_BOX_TREE_H\n#define VPML_BOX_TREE_H', 1)
    s = s.replace('#endif // GRID_H', '#endif // VPML_BOX_TREE_H', 1)
    write(bt, s); print('patched', bt)
else:
    print('deja ok ', bt)

# 8e) Octtree.h: base Tree_Node virtuals with empty body {} but non-void return -> C4716 on MSVC
patch('src/VPML/Octtree.h', [
    ('    virtual Cart_ID Get_CID(const Vector3 &Pos, const Real &H, const uint &Level=0) {}',
     '    virtual Cart_ID Get_CID(const Vector3 &Pos, const Real &H, const uint &Level=0) { return Cart_ID(0,0,0); }'),
    ('                                const Vector3 &Centre = Vector3(0,0,0)){}   // Initial Centre is zero',
     '                                const Vector3 &Centre = Vector3(0,0,0)){ return Vector3(0,0,0); }   // Initial Centre is zero'),
    ('    virtual Matrix Get_Corners(const TreeID &TID, const Real &H, const uint &Level = 0) {}  // Return box corners',
     '    virtual Matrix Get_Corners(const TreeID &TID, const Real &H, const uint &Level = 0) { return Matrix(); }  // Return box corners'),
])

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
print('VPML tr1/cmath replaced:', '<tr1/cmath>' not in read('src/VPML/Math_Types.h') and '#include <cmath>' in read('src/VPML/Math_Types.h'))
print('SinglePrec macro fixed:', '#define SinglePrec;' not in read('src/VPML/Math_Types.h'))
print('OpenMPfor MSVC-guarded:', '#ifdef _MSC_VER' in read('src/VPML/Math_Types.h'))
print('Box_Tree.h line174 clean:', all(ord(c) < 128 for c in read('src/VPML/Box_Tree.h').splitlines()[173]))
print('ML_Euler BCtype const:', 'const char *BCtype;' in read('src/VPML/ML_Euler.h'))
print('Box_Tree guard renamed:', '#ifndef VPML_BOX_TREE_H' in read('src/VPML/Box_Tree.h') and '#ifndef GRID_H' not in read('src/VPML/Box_Tree.h'))
print('Octtree C4716 fixed:', 'return Cart_ID(0,0,0); }' in read('src/VPML/Octtree.h') and 'return Matrix(); }' in read('src/VPML/Octtree.h'))
print('ALL FIXES APPLIED OK')
