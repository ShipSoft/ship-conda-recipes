#!/bin/bash
set -euxo pipefail

# GENIE's build system requires $GENIE to point at the source tree.
export GENIE="${SRC_DIR}"

# Hadronization/decay backend, selected by the genie_hadronization
# variant (see variants.yaml) and passed in via the script env.
case "${GENIE_HADRONIZATION}" in
    pythia6)
        hadronization_flags=(
            --enable-pythia6
            --with-pythia6-lib="${PREFIX}/lib"
            --disable-pythia8
        )
        ;;
    pythia8)
        hadronization_flags=(
            --disable-pythia6
            --enable-pythia8
            --with-pythia8-inc="${PREFIX}/include"
            --with-pythia8-lib="${PREFIX}/lib"
        )
        ;;
    *)
        echo "unknown GENIE_HADRONIZATION: ${GENIE_HADRONIZATION}" >&2
        exit 1
        ;;
esac

# configure is a hand-rolled perl script (not autoconf); invoke it via the
# build environment's perl (there is no /usr/bin/perl on e.g. NixOS).
perl ./configure \
    --prefix="${PREFIX}" \
    "${hadronization_flags[@]}" \
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

# GENIE needs its config XML at runtime ($GENIE/config) but 'make install'
# does not ship it. genie-config additionally sources
# $GENIE/src/make/Make.config_no_paths and reads $GENIE/VERSION. Stage all
# of that under share/genie and point $GENIE there via an activation
# script. The (much larger, variant-independent) $GENIE/data tree is
# shipped by the genie-data package into the same share/genie prefix.
mkdir -p "${PREFIX}/share/genie/src/make"
cp -r "${GENIE}/config" "${PREFIX}/share/genie/"
cp "${GENIE}/VERSION" "${PREFIX}/share/genie/"
cp "${GENIE}"/src/make/Make.config* "${PREFIX}/share/genie/src/make/"

mkdir -p "${PREFIX}/etc/conda/activate.d" "${PREFIX}/etc/conda/deactivate.d"
cat > "${PREFIX}/etc/conda/activate.d/genie-activate.sh" <<'EOF'
export GENIE="${CONDA_PREFIX}/share/genie"
# GENIE's rootmaps reference headers relative to the include root
# (e.g. Framework/Algorithm/Algorithm.h), so ROOT's cling autoloader needs
# include/GENIE on ROOT_INCLUDE_PATH; without it, loading any genie:: type
# floods stderr with "Missing FileEntry" errors. Back up/restore around our
# prepend, mirroring the root package's activate-root.sh pattern.
if [ -n "${ROOT_INCLUDE_PATH:-}" ]; then
	export CONDA_BACKUP_ROOT_INCLUDE_PATH="${ROOT_INCLUDE_PATH}"
fi
export ROOT_INCLUDE_PATH="${CONDA_PREFIX}/include/GENIE${ROOT_INCLUDE_PATH:+:${ROOT_INCLUDE_PATH}}"
EOF
cat > "${PREFIX}/etc/conda/deactivate.d/genie-deactivate.sh" <<'EOF'
unset GENIE
if [ -n "${CONDA_BACKUP_ROOT_INCLUDE_PATH:-}" ]; then
	export ROOT_INCLUDE_PATH="${CONDA_BACKUP_ROOT_INCLUDE_PATH}"
	unset CONDA_BACKUP_ROOT_INCLUDE_PATH
else
	unset ROOT_INCLUDE_PATH
fi
EOF
