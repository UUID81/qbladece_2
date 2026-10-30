#!/usr/bin/env bash
# Fix MSVC error C2632: Windows SDK macro 'small' (rpcndr.h) clashes with
# local variables in FoilModule.cpp -> rename small/large to smallVal/largeVal
set -e
cd "$(dirname "$0")/.."
sed -i '1416,1432{s/\bsmall\b/smallVal/g; s/\blarge\b/largeVal/g}' src/FoilModule/FoilModule.cpp
echo "--- verification ---"
grep -n "smallVal\|largeVal" src/FoilModule/FoilModule.cpp
if grep -qn "double small \|double large " src/FoilModule/FoilModule.cpp; then
  echo "ERREUR: il reste des 'small'/'large' non renommes"
  exit 1
fi
echo "OK: renommage applique"
