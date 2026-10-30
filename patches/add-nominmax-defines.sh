#!/usr/bin/env bash
# Inserts into qblade.pro, right after the "unix: DEFINES += compiled_string=..." line:
#   win32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS
# Run FROM THE REPO ROOT. CRLF-proof invocation if your checkout converted this file:
#   bash -c "$(tr -d '\r' < patches/add-nominmax-defines.sh)"
# Direct one-liner (copy-paste safe, works with CRLF checkout too):
#   sed -i "s/^\(unix:   DEFINES += compiled_string=.*\)\r\?$/\1\nwin32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS/" qblade.pro
sed -i "s/^\(unix:   DEFINES += compiled_string=.*\)\r\?$/\1\nwin32:  DEFINES += NOMINMAX WIN32_LEAN_AND_MEAN _CRT_NONSTDC_NO_WARNINGS/" qblade.pro
grep -n "NOMINMAX" qblade.pro
