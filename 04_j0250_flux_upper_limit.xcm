#!/usr/bin/env bash
set -euo pipefail

# Create cleaned EPIC-pn images for each observation and merge them into a mosaic.
# Run this script from the directory that contains the ObsID subdirectories.

: > images.txt

for dir in */ ; do
    cd "$dir"

    evt_file=$(ls *PIEVLI*.FIT 2>/dev/null | head -n 1 || true)

    if [[ -n "${evt_file}" ]]; then
        echo "-> ${dir}: generating cleaned image..."

        evselect table="${evt_file}" \
            withfilteredset=yes \
            filteredset=pn_clean.fits \
            destruct=yes \
            keepfilteroutput=yes \
            expression='(PI in [200:10000]) && (PATTERN<=4) && (FLAG==0)'

        evselect table=pn_clean.fits \
            imagebinning=binSize \
            imageset=image_clean.fits \
            withimageset=yes \
            xcolumn=X ycolumn=Y \
            ximagebinsize=80 yimagebinsize=80

        echo "$(pwd)/image_clean.fits" >> ../images.txt
    else
        echo "!! Event file not found in ${dir}."
    fi

    cd ..
done

if [[ -s images.txt ]]; then
    emosaic imagesets="$(paste -sd ' ' images.txt)" mosaicedset=final_mosaic.fits
    echo "Mosaic created: final_mosaic.fits"
else
    echo "No images were created; mosaic step skipped."
fi
