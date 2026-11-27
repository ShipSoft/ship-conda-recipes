# Remove this environment's lib directory from PHLEX_PLUGIN_PATH and unset the
# variable if nothing else is left in it.
if ( $?PHLEX_PLUGIN_PATH ) then
    setenv PHLEX_PLUGIN_PATH "`awk -v c=: -v l=/lib -v k=CONDA_PREFIX -v v=PHLEX_PLUGIN_PATH 'BEGIN { d = ENVIRON[k] l; n = split(ENVIRON[v], a, c); for (i = 1; i <= n; i++) { if (a[i] == d) continue; s = (j++ ? s c : s) a[i] } print s }'`"
    if ( "$PHLEX_PLUGIN_PATH" == "" ) unsetenv PHLEX_PLUGIN_PATH
endif
