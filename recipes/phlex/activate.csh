# Prepend this environment's lib directory to PHLEX_PLUGIN_PATH unless it is
# already listed. conda re-runs this script when a stacked environment is
# deactivated, so it must be idempotent. awk compares whole entries as plain
# strings, so the prefix may contain any character.
if ( $?PHLEX_PLUGIN_PATH ) then
    setenv PHLEX_PLUGIN_PATH "`awk -v c=: -v l=/lib -v k=CONDA_PREFIX -v v=PHLEX_PLUGIN_PATH 'BEGIN { d = ENVIRON[k] l; p = ENVIRON[v]; n = split(p, a, c); for (i = 1; i <= n; i++) if (a[i] == d) { print p; exit } if (length(p) == 0) print d; else print d c p }'`"
else
    setenv PHLEX_PLUGIN_PATH "${CONDA_PREFIX}/lib"
endif
