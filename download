#!/usr/bin/env bash
set -euo pipefail

# Automated spectral extraction, stacking, and grouping for RX J1856.5-3754.
# Run this script from the directory that contains the ObsID subdirectories.

rm -f source_list.txt bkg_list.txt rmf_list.txt arf_list.txt

# Source and background coordinates for RX J1856.5-3754
RA_SRC=284.1505
DEC_SRC=-37.9101
RA_BKG=284.1226
DEC_BKG=-37.9195

# ObsIDs excluded in the thesis workflow
SKIP_REGEX='^(412601501|791580101|791580201|791580401|791580501)$'

for dir in */ ; do
    obsid="${dir%/}"

    if [[ ! "${obsid}" =~ ^[0-9]{10}$ ]]; then
        continue
    fi

    if [[ "${obsid}" =~ ${SKIP_REGEX} ]]; then
        echo "STOP [SKIPPING] ${obsid}"
        continue
    fi

    cd "${dir}"
    echo "Processing: ${obsid}"

    rm -f ccf.cif *SUM.SAS pn_clean.fits pn_source_spec.fits pn_bkg_spec.fits pn.rmf pn.arf

    export SAS_ODF="$(pwd)"
    cifbuild fullpath=yes >/dev/null 2>&1
    export SAS_CCF="$(pwd)/ccf.cif"
    odfingest odfdir="$(pwd)" outdir="$(pwd)" >/dev/null 2>&1
    export SAS_ODF="$(ls -1 *SUM.SAS | head -n 1)"

    raw_evt=$(ls *PIEVLI*.FIT 2>/dev/null | head -n 1 || true)

    if [[ -z "${raw_evt}" ]]; then
        echo "-> [SKIP] No event file found."
        cd ..
        continue
    fi

    evselect table="${raw_evt}" \
        withfilteredset=yes \
        filteredset=pn_clean.fits \
        keepfilteroutput=yes \
        expression='(PATTERN<=4) && (FLAG==0) && (PI in [200:10000])' \
        destruct=yes updateexposure=yes filtertype=expression writedss=yes >/dev/null 2>&1

    if [[ ! -s pn_clean.fits ]]; then
        echo "-> [SKIP] cleaned event file was not created."
        cd ..
        continue
    fi

    # Convert RA/DEC to detector coordinates.
    coords_src=$(ecoordconv imageset=pn_clean.fits x="${RA_SRC}" y="${DEC_SRC}" coordtype=eqpos)
    x_src=$(echo "${coords_src}" | grep 'X:' | awk '{print $2}' | cut -d. -f1)
    y_src=$(echo "${coords_src}" | grep 'Y:' | awk '{print $4}' | cut -d. -f1)

    coords_bkg=$(ecoordconv imageset=pn_clean.fits x="${RA_BKG}" y="${DEC_BKG}" coordtype=eqpos)
    x_bkg=$(echo "${coords_bkg}" | grep 'X:' | awk '{print $2}' | cut -d. -f1)
    y_bkg=$(echo "${coords_bkg}" | grep 'Y:' | awk '{print $4}' | cut -d. -f1)

    if [[ -z "${x_src}" || -z "${x_bkg}" ]]; then
        echo "-> [WARNING] Coordinates out of detector range."
        cd ..
        continue
    fi

    evselect table=pn_clean.fits \
        withspectrumset=yes \
        spectrumset=pn_source_spec.fits \
        energycolumn=PI spectralbinsize=5 \
        withspecranges=yes specchannelmin=0 specchannelmax=20479 \
        expression="((X,Y) IN circle(${x_src},${y_src},300)) && (FLAG==0) && (PATTERN<=4)" >/dev/null 2>&1

    evselect table=pn_clean.fits \
        withspectrumset=yes \
        spectrumset=pn_bkg_spec.fits \
        energycolumn=PI spectralbinsize=5 \
        withspecranges=yes specchannelmin=0 specchannelmax=20479 \
        expression="((X,Y) IN circle(${x_bkg},${y_bkg},300)) && (FLAG==0) && (PATTERN<=4)" >/dev/null 2>&1

    if [[ -s pn_source_spec.fits && -s pn_bkg_spec.fits ]]; then
        backscale spectrumset=pn_source_spec.fits badpixlocation=pn_clean.fits >/dev/null 2>&1
        backscale spectrumset=pn_bkg_spec.fits badpixlocation=pn_clean.fits >/dev/null 2>&1

        rmfgen spectrumset=pn_source_spec.fits rmfset=pn.rmf >/dev/null 2>&1
        arfgen spectrumset=pn_source_spec.fits arfset=pn.arf withrmfset=yes rmfset=pn.rmf \
            badpixlocation=pn_clean.fits detmaptype=flat >/dev/null 2>&1

        if [[ -s pn.arf ]]; then
            echo "-> [ADDED] Files added to stack list."
            echo "$(pwd)/pn_source_spec.fits" >> ../source_list.txt
            echo "$(pwd)/pn_bkg_spec.fits" >> ../bkg_list.txt
            echo "$(pwd)/pn.rmf" >> ../rmf_list.txt
            echo "$(pwd)/pn.arf" >> ../arf_list.txt
        fi
    fi

    cd ..
done

if [[ -s source_list.txt ]]; then
    epicspeccombine \
        pha='@source_list.txt' \
        bkg='@bkg_list.txt' \
        rmf='@rmf_list.txt' \
        arf='@arf_list.txt' \
        filepha='RXJ1856_clean_v9.fits' \
        filebkg='RXJ1856_clean_v9_bkg.fits' \
        filersp='RXJ1856_clean_v9.rsp'

    grppha \
        infile=RXJ1856_clean_v9.fits \
        outfile=RXJ1856_grp200.fits \
        comm="group min 200 & chkey BACKFILE RXJ1856_clean_v9_bkg.fits & chkey RESPFILE RXJ1856_clean_v9.rsp & exit"

    echo "Complete: RXJ1856_grp200.fits"
else
    echo "Stacking failed: source_list.txt is empty."
fi
