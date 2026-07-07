#!/bin/bash
set -euxo pipefail

share_dir="${PREFIX}/share/genie-splines-ship"

if [ -n "${GENIE_SPLINES_PREBUILT:-}" ]; then
    # Production path: the splines workflow
    # (.github/workflows/splines.yml) generated the full spline set on
    # CI runners, merged it with gspladd, and injects the merged XML via
    # GENIE_SPLINES_PREBUILT and its provenance file via
    # GENIE_SPLINES_PREBUILT_PROVENANCE.
    install -D -m 644 "${GENIE_SPLINES_PREBUILT}" \
        "${share_dir}/gxspl-ship.xml"
    install -D -m 644 "${GENIE_SPLINES_PREBUILT_PROVENANCE}" \
        "${share_dir}/PROVENANCE"
else
    # Smoke path (local / PR CI): generate a reduced spline set with
    # the genie package from the build environment. gmkspl needs
    # $GENIE for config and data; the activation script may not have
    # run here, so set it explicitly.
    export GENIE="${BUILD_PREFIX}/share/genie"

    gmkspl \
        -p "${SPLINE_PDGS}" \
        -t "${SPLINE_TARGETS}" \
        -n "${SPLINE_KNOTS}" \
        -e "${SPLINE_EMAX}" \
        --event-generator-list "${SPLINE_GEN_LIST}" \
        --tune "${GENIE_TUNE}" \
        -o gxspl-ship.xml

    install -D -m 644 gxspl-ship.xml "${share_dir}/gxspl-ship.xml"
    {
        echo "source: smoke (generated at package build time)"
        echo "tune: ${GENIE_TUNE}"
        echo "flavours: ${SPLINE_PDGS}"
        echo "targets: ${SPLINE_TARGETS}"
        echo "knots: ${SPLINE_KNOTS}"
        echo "emax-gev: ${SPLINE_EMAX}"
        echo "event-generator-list: ${SPLINE_GEN_LIST}"
    } > "${share_dir}/PROVENANCE"
fi

# Convention used by several GENIE-based frameworks to locate the
# spline file.
mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
cat > "${PREFIX}/etc/conda/activate.d/genie-splines-ship-activate.sh" <<'EOF'
export GENIE_XSEC_FILE="${CONDA_PREFIX}/share/genie-splines-ship/gxspl-ship.xml"
EOF
cat > "${PREFIX}/etc/conda/deactivate.d/genie-splines-ship-deactivate.sh" <<'EOF'
unset GENIE_XSEC_FILE
EOF
