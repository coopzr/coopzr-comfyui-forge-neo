#!/usr/bin/env bash
# Points a copied venv at its new location.
# Adapted from ashleykleynhans/runpod-base-images scripts/fix_venv.sh (GPL-3.0).
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <OLD_VENV> <NEW_VENV>"
    echo "   eg: $0 /venv /workspace/venv"
    exit 1
fi
OLD_PATH=${1}
NEW_PATH=${2}
echo "VENV: Fixing venv. Old Path: ${OLD_PATH}  New Path: ${NEW_PATH}"
cd "${NEW_PATH}/bin" || exit 1

# Check if VIRTUAL_ENV line contains quotes or not
if grep -q "VIRTUAL_ENV=\"${OLD_PATH}\"" activate; then
    echo "Found VIRTUAL_ENV with quotes"
    sed -i "s|VIRTUAL_ENV=\"${OLD_PATH}\"|VIRTUAL_ENV=\"${NEW_PATH}\"|" activate
elif grep -q "VIRTUAL_ENV=${OLD_PATH}" activate; then
    echo "Found VIRTUAL_ENV without quotes"
    sed -i "s|VIRTUAL_ENV=${OLD_PATH}|VIRTUAL_ENV=${NEW_PATH}|" activate
else
    echo "Warning: Could not find VIRTUAL_ENV=${OLD_PATH} in activate script"
fi

# Update the venv path in the shebang of every script in bin/
# (matches python, python3 and python3.13).
find . -maxdepth 1 -type f -exec grep -l "^#!${OLD_PATH}/bin/python" {} \; |
    while read -r file; do
        sed -i "s|^#!${OLD_PATH}/bin/python|#!${NEW_PATH}/bin/python|" "$file"
    done
