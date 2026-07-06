#!/bin/bash
set -euxo pipefail

# GENIE's build system requires $GENIE to point at the source tree.
export GENIE="${SRC_DIR}"

# configure is a hand-rolled perl script (not autoconf); invoke it via the
# build environment's perl (there is no /usr/bin/perl on e.g. NixOS).
perl ./configure \
    --prefix="${PREFIX}" \
    --enable-pythia6 \
    --with-pythia6-lib="${PREFIX}/lib" \
    --disable-lhapdf5 \
    --enable-lhapdf6 \
    --with-lhapdf6-inc="${PREFIX}/include" \
    --with-lhapdf6-lib="${PREFIX}/lib" \
    --with-libxml2-inc="${PREFIX}/include/libxml2" \
    --with-libxml2-lib="${PREFIX}/lib" \
    --with-log4cpp-inc="${PREFIX}/include" \
    --with-log4cpp-lib="${PREFIX}/lib" \
    --enable-flux-drivers \
    --enable-geom-drivers \
    --enable-fnal \
    --enable-atmo

# Make.include hardwires CXX=g++/LD=g++ and overwrites LDFLAGS, so force the
# conda toolchain and re-append conda's LDFLAGS (for -rpath $PREFIX/lib) on
# the make command line; command-line values propagate to all sub-makes.
MAKE_OVERRIDES=(
    CC="${CC}"
    CXX="${CXX}"
    LD="${CXX}"
    LDFLAGS="${LDFLAGS} -g -Wl,--no-as-needed -Wl,--no-undefined"
)
make -j"${CPU_COUNT}" "${MAKE_OVERRIDES[@]}"

# 'make install' is not parallel-safe (per upstream / spack recipe).
make install "${MAKE_OVERRIDES[@]}"

# 'make install' only installs libraries and headers; the app binaries and
# the genie-config/genie scripts are left in $GENIE/bin.
install -m 755 "${GENIE}"/bin/* "${PREFIX}/bin/"

# GENIE needs its config and data XML/tables at runtime ($GENIE/config,
# $GENIE/data) but 'make install' does not ship them. genie-config
# additionally sources $GENIE/src/make/Make.config_no_paths and reads
# $GENIE/VERSION. Stage all of that under share/genie and point $GENIE
# there via an activation script.
mkdir -p "${PREFIX}/share/genie/src/make"
cp -r "${GENIE}/config" "${PREFIX}/share/genie/"
cp -r "${GENIE}/data" "${PREFIX}/share/genie/"
cp "${GENIE}/VERSION" "${PREFIX}/share/genie/"
cp "${GENIE}"/src/make/Make.config* "${PREFIX}/share/genie/src/make/"

mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
cat > "${PREFIX}/etc/conda/activate.d/genie-activate.sh" <<'EOF'
export GENIE="${CONDA_PREFIX}/share/genie"
EOF
cat > "${PREFIX}/etc/conda/deactivate.d/genie-deactivate.sh" <<'EOF'
unset GENIE
EOF
