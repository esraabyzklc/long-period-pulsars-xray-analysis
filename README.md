#!/usr/bin/env bash
set -euo pipefail

# Image creation, exposure-map generation, and ML source detection with edetect_chain
# for PSR J0250+5854.

BASE_DIR="${BASE_DIR:-/path/to/PSR_J0250}"
OBSIDS=(0844000201 0844000301 0844000401 0844000501 0844000701 0844000901 0844001101 0844001201)
PN_CLEAN="pn_clean.fits"

for ID in "${OBSIDS[@]}"; do
    echo "Processing Observation ID: ${ID}"

    if [[ -d "${BASE_DIR}/${ID}" ]]; then
        cd "${BASE_DIR}/${ID}"
    else
        echo "Error: Directory for ${ID} not found. Skipping."
        continue
    fi

    export SAS_ODF="$(pwd)"
    if [[ ! -f ccf.cif ]]; then
        cifbuild fullpath=yes
    fi
    export SAS_CCF="$(pwd)/ccf.cif"

    sum_file=$(ls *SUM.SAS 2>/dev/null | head -n 1 || true)
    if [[ -z "${sum_file}" ]]; then
        odfingest odfdir="$(pwd)" outdir="$(pwd)"
        sum_file=$(ls *SUM.SAS | head -n 1)
    fi
    export SAS_ODF="${sum_file}"

    attfile=$(ls *ATTTSR*.FIT 2>/dev/null | head -n 1 || true)
    if [[ -z "${attfile}" ]]; then
        echo "Error: Attitude file missing for ${ID}. Skipping."
        continue
    fi

    if [[ ! -f "${PN_CLEAN}" ]]; then
        echo "Error: ${PN_CLEAN} not found for ${ID}. Run the event-cleaning step first."
        continue
    fi

    evselect table="${PN_CLEAN}" \
        imagebinning=binSize \
        imageset=image_clean.fits \
        withimageset=yes \
        xcolumn=X ycolumn=Y \
        ximagebinsize=80 yimagebinsize=80 \
        ximagesize=600 yimagesize=600 \
        expression='(PI>200) && (PI<12000) && (FLAG==0) && (PATTERN<=4)'

    eexpmap \
        imageset=image_clean.fits \
        attitudeset="${attfile}" \
        eventset="${PN_CLEAN}" \
        expimageset=exposure_map.fits \
        pimin=200 pimax=12000

    edetect_chain \
        imagesets=image_clean.fits \
        eventsets="${PN_CLEAN}" \
        attitudeset="${attfile}" \
        expimagesets=exposure_map.fits \
        pimin=200 pimax=12000 \
        likemin=8 \
        eml_list=emllist.fits \
        box_list=boxlist.fits \
        bkgimagesets=bkg_map.fits

    srcdisplay \
        boxlistset=emllist.fits \
        imageset=image_clean.fits \
        regionfile=region.reg \
        sourceradius=0.01 \
        withregionfile=yes \
        withimgdisplay=no

    echo "Observation ID ${ID} processing complete."
done
