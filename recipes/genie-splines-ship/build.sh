#!/bin/bash
set -euxo pipefail

# genie lives in the build environment (gmkspl runs at build time);
# its activation script may not have run here, so set $GENIE (config +
# data tree) explicitly.
export GENIE="${BUILD_PREFIX}/share/genie"

# Spline configuration comes from the recipe context via the script env
# (see recipe.yaml; currently the smoke configuration).
gmkspl \
    -p "${SPLINE_PDGS}" \
    -t "${SPLINE_TARGETS}" \
    -n "${SPLINE_KNOTS}" \
    -e "${SPLINE_EMAX}" \
    --event-generator-list "${SPLINE_GEN_LIST}" \
    --tune "${GENIE_TUNE}" \
    -o gxspl-ship.xml

install -D -m 644 gxspl-ship.xml \
    "${PREFIX}/share/genie-splines-ship/gxspl-ship.xml"

# Convention used by several GENIE-based frameworks to locate the
# spline file.
mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
cat > "${PREFIX}/etc/conda/activate.d/genie-splines-ship-activate.sh" <<'EOF'
export GENIE_XSEC_FILE="${CONDA_PREFIX}/share/genie-splines-ship/gxspl-ship.xml"
EOF
cat > "${PREFIX}/etc/conda/deactivate.d/genie-splines-ship-deactivate.sh" <<'EOF'
unset GENIE_XSEC_FILE
EOF
