"""Cling's view of Pythia 8 must match the libpythia8 in the environment.

ROOT's EGPythia8 C++ module embeds the Pythia 8 headers it was built with.
Against another Pythia 8 release, PyROOT reads Pythia8 members at the wrong
offsets (particleData.m0(211) returned 0.0 with an 8.312 module and an 8.318
library), and libEGPythia8 fails to load on missing symbols.
"""

import ROOT

assert ROOT.gSystem.Load("libEGPythia8") >= 0, "cannot load libEGPythia8"

pythia = ROOT.TPythia8().Pythia8()
library = round(pythia.settings.parm("Pythia:versionNumber") * 1000)
headers = int(ROOT.gInterpreter.ProcessLine("PYTHIA_VERSION_INTEGER;"))
print(f"libpythia8 {library}, cling headers {headers}")
assert library == headers, "EGPythia8 module built against another Pythia 8"

m_pi = pythia.particleData.m0(211)
print(f"pi+ mass {m_pi}")
assert abs(m_pi - 0.13957) < 1e-4, "PyROOT reads Pythia8 members at wrong offsets"
