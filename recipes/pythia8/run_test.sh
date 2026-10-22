#!/usr/bin/env bash

# shellcheck disable=SC2046,SC2154  # pythia8-config flags must word-split; build_platform/target_platform come from the build environment
set -ex

cat ${PREFIX}/share/Pythia8/examples/Makefile.inc

pythia8-config --help

pythia8-config --cxxflags

pythia8-config --ldflags

echo ""
_with_lhapdf6=$(pythia8-config --with-lhapdf6)
if [[ "${_with_lhapdf6}" == "true" ]]; then
    echo -e "# pythia8-config --with-lhapdf6: ${_with_lhapdf6}"
else
    echo "pythia8-config --with-lhapdf6 is ${_with_lhapdf6} but should be true"
    exit 1
fi
unset _with_lhapdf6

echo ""
_with_fastjet3=$(pythia8-config --with-fastjet3)
if [[ "${_with_fastjet3}" == "true" ]]; then
    echo -e "# pythia8-config --with-fastjet3: ${_with_fastjet3}"
else
    echo "pythia8-config --with-fastjet3 is ${_with_fastjet3} but should be true"
    exit 1
fi
unset _with_fastjet3

echo ""
_with_hepmc2=$(pythia8-config --with-hepmc2)
if [[ "${_with_hepmc2}" == "true" ]]; then
    echo -e "# pythia8-config --with-hepmc2: ${_with_hepmc2}"
else
    echo "pythia8-config --with-hepmc2 is ${_with_hepmc2} but should be true"
    exit 1
fi
unset _with_hepmc2

echo ""
_with_hepmc3=$(pythia8-config --with-hepmc3)
if [[ "${_with_hepmc3}" == "true" ]]; then
    echo -e "# pythia8-config --with-hepmc3: ${_with_hepmc3}"
else
    echo "pythia8-config --with-hepmc3 is ${_with_hepmc3} but should be true"
    exit 1
fi
unset _with_hepmc3

echo ""
_with_gzip=$(pythia8-config --with-gzip)
if [[ "${_with_gzip}" == "true" ]]; then
    echo -e "# pythia8-config --with-gzip: ${_with_gzip}"
else
    echo "pythia8-config --with-gzip is ${_with_gzip} but should be true"
    exit 1
fi
unset _with_gzip

echo ""
_with_python=$(pythia8-config --with-python)
if [[ "${_with_python}" == "true" ]]; then
    echo -e "# pythia8-config --with-python: ${_with_python}"
else
    echo "pythia8-config --with-python is ${_with_python} but should be true"
    exit 1
fi
unset _with_python

echo ""
_with_mg5mes=$(pythia8-config --with-mg5mes)
if [[ "${_with_mg5mes}" == "true" ]]; then
    echo -e "# pythia8-config --with-mg5mes: ${_with_mg5mes}"
else
    echo "pythia8-config --with-mg5mes is ${_with_mg5mes} but should be true"
    exit 1
fi
unset _with_mg5mes

cd examples/
make clean

# The v2+ versions of conda-forge compiler metapackages install minimally
# activated compilers where the compiler toolchain works by explicit name
# but environmental variables like CXX are no longer set.
# c.f. https://github.com/conda-forge/conda-forge.github.io/issues/2595
if [[ -z "${CXX:-}" ]]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        CXX="clang++"
    else
        CXX="g++"
    fi
fi

"$CXX" main101.cc -o main101 $(pythia8-config --cxxflags --ldflags)
./main101 &> main101_output.txt || ./main101

# Exit early under emulation
if [[ "${build_platform}" != "${target_platform}" ]]; then
    echo -e "\n# Target platform ${target_platform} requires emulation on"\
        "${build_platform} runners and will be too slow to run the full tests,"\
        "and so is being skipped."
    exit 0
fi

echo -e "\n# Test example main161 that uses the FastJet library extension"
make clean
# avoid lots of output to stdout from download of the file
lhapdf install cteq6l1 &> /dev/null

"$CXX" main161.cc -o main161 $CXXFLAGS $LDFLAGS -lpythia8 -lfastjet
./main161 -c main161.cmnd -i w+_production_lhc_0.lhe -o histout161.dat &> main161_output.txt || ./main161 main161.cmnd w+_production_lhc_0.lhe histout161.dat

echo -e "\n# Test example main201 that uses the LHAPDF library extension"
make clean
# avoid lots of output to stdout from download of the file
lhapdf install NNPDF31_nnlo_as_0118_luxqed &> /dev/null

# The examples assume you built locally and didn't install, so need to patch
# the relative path (../share) to the absolute path ($PREFIX/share)
sed -i "s|../share|$(readlink -f $PREFIX/share)|g" main201.cc

"$CXX" main201.cc -o main201 $(pythia8-config --cxxflags --ldflags)
./main201 &> main201_output.txt || ./main201

echo -e "\n# Test example main212 that uses the FastJet library extension"
make clean

"$CXX" main212.cc -o main212 $(pythia8-config --cxxflags --ldflags) -lpythia8 -lfastjet
./main212 &> main212_output.txt || ./main212

echo -e "\n# Test example that use the HepMC2 and HepMC3 extensions"
"$CXX" main131.cc -o main131 $(pythia8-config --cxxflags --ldflags) -lpythia8 -lHepMC3
./main131 &> main131_output.txt || ./main131
test -f main131.hepmc

"$CXX" main132.cc -o main132 $(pythia8-config --cxxflags --ldflags) -lpythia8 -lHepMC3
./main132 -c main132.cmnd -o main132.hepmc &> main132_output.txt || ./main132 main132.cmnd main132.hepmc
test -f main132.hepmc

"$CXX" main133.cc -o main133 $(pythia8-config --cxxflags --ldflags) -lpythia8 -lHepMC3
./main133 -c main133.cmnd -o main133.hepmc &> main133_output.txt || ./main133 main133.cmnd main133.hepmc
test -f main133.hepmc

"$CXX" main134.cc -o main134 $(pythia8-config --cxxflags --ldflags) -lpythia8 -lHepMC3
./main134 -c main134.cmnd -o main134.hepmc &> main134_output.txt || ./main134 main134.cmnd main134.hepmc
test -f main134.hepmc

"$CXX" main135.cc -o main135 $(pythia8-config --cxxflags --ldflags) -lpythia8 -lHepMC3
./main135 &> main135_output.txt || ./main135
test -f main135.hepmc
