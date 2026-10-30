#!/usr/bin/env bash
# Round 2 MSVC fixes:
#  - StoreAssociatedComboBox.h: include StorableObject.h (fixes C2440 T* -> StorableObject*)
#  - StrModel.cpp line 1576: isnan -> std::isnan (fixes C2668 fpclassify ambiguous)
set -e
cd "$(dirname "$0")/.."
sed -i 's|#include "StoreAssociatedComboBox_include.h"|#include "StoreAssociatedComboBox_include.h"\n#include "StorableObject.h"|' src/StoreAssociatedComboBox.h
sed -i '/^class StorableObject;$/d' src/StoreAssociatedComboBox.h
sed -i '1576s/\bisnan(/std::isnan(/' src/StructModel/StrModel.cpp
echo "--- verification ---"
grep -n "StorableObject.h" src/StoreAssociatedComboBox.h
grep -n "std::isnan(angle)" src/StructModel/StrModel.cpp
echo "OK: round2 applique"
