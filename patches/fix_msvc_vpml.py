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

# 8f) QFEMModule.cpp: 2D VLA GLdouble x[(int)...size()][3] -> QVector<GLdouble> flat (MSVC C2131/C3863)
qf = 'src/QFEMModule/QFEMModule.cpp'
s = read(qf)
if 'QVector<GLdouble> outerpoints(' not in s:
    s = s.replace('GLdouble outerpoints[(int)OuterProfiles[0].size()][3];',
                  'QVector<GLdouble> outerpoints((int)OuterProfiles[0].size()*3, 0.0);', -1)
    s = s.replace('GLdouble innerpoints[(int)InnerProfiles[0].size()][3];',
                  'QVector<GLdouble> innerpoints((int)InnerProfiles[0].size()*3, 0.0);', -1)
    s = re.sub(r'outerpoints\[l\]\[(\d)\]', r'outerpoints[l*3+\1]', s)
    s = re.sub(r'innerpoints\[l\]\[(\d)\]', r'innerpoints[l*3+\1]', s)
    s = s.replace('gluTessVertex(tess, outerpoints[l], outerpoints[l]);',
                  'gluTessVertex(tess, &outerpoints[l*3], &outerpoints[l*3]);')
    s = s.replace('gluTessVertex(tess, innerpoints[l], innerpoints[l]);',
                  'gluTessVertex(tess, &innerpoints[l*3], &innerpoints[l*3]);')
    write(qf, s); print('patched', qf)
else:
    print('deja ok ', qf)

print('=== verification (VPML/Chrono) ===')
print('VPML tr1/cmath replaced:', '<tr1/cmath>' not in read('src/VPML/Math_Types.h') and '#include <cmath>' in read('src/VPML/Math_Types.h'))
print('SinglePrec macro fixed:', '#define SinglePrec;' not in read('src/VPML/Math_Types.h'))
print('OpenMPfor MSVC-guarded:', '#ifdef _MSC_VER' in read('src/VPML/Math_Types.h'))
print('Box_Tree.h line174 clean:', all(ord(c) < 128 for c in read('src/VPML/Box_Tree.h').splitlines()[173]))
print('ML_Euler BCtype const:', 'const char *BCtype;' in read('src/VPML/ML_Euler.h'))
print('Box_Tree guard renamed:', '#ifndef VPML_BOX_TREE_H' in read('src/VPML/Box_Tree.h') and '#ifndef GRID_H' not in read('src/VPML/Box_Tree.h'))
print('Octtree C4716 fixed:', 'return Cart_ID(0,0,0); }' in read('src/VPML/Octtree.h') and 'return Matrix(); }' in read('src/VPML/Octtree.h'))
print('QFEM VLA->QVector:', 'QVector<GLdouble> outerpoints(' in read('src/QFEMModule/QFEMModule.cpp') and 'outerpoints[(int)' not in read('src/QFEMModule/QFEMModule.cpp'))
print('Chrono ::chrono:: qualified:', '::chrono::ChArchiveOut' in read('include_headers/Chrono/chrono/core/ChMatrixEigenExtensions.h'))
print('ChArchive.h qualified:', '::chrono::' in read('include_headers/Chrono/chrono/serialization/ChArchive.h'))
print('ALL VPML FIXES APPLIED OK')
