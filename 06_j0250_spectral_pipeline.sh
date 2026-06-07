#!/usr/bin/env bash
set -euo pipefail

# Generate calibrated EPIC-pn event files for each XMM-Newton observation folder.
# Run this script from the directory that contains the ObsID subdirectories.

for dir in */ ; do
    echo "=========================================="
    echo "PROCESSING: ${dir}"
    echo "=========================================="

    cd "$dir"

    export SAS_ODF="$(pwd)"

    if [[ ! -f ccf.cif ]]; then
        echo "-> generating CCF..."
        cifbuild fullpath=yes
    fi
    export SAS_CCF="$(pwd)/ccf.cif"

    if ! ls *SUM.SAS >/dev/null 2>&1; then
        echo "-> generating ODF summary..."
        odfingest odfdir="$(pwd)" outdir="$(pwd)"
    fi
    export SAS_ODF="$(ls *SUM.SAS | head -n 1)"

    if ! ls *PIEVLI* >/dev/null 2>&1; then
        echo "-> epchain starting..."
        epchain
        echo "-> processing completed for ${dir}"
    else
        echo "-> event file already exists, skipping epchain."
    fi

    cd ..
done
