# Prepend this environment's lib directory to PHLEX_PLUGIN_PATH unless it is
# already listed. conda re-runs this script when a stacked environment is
# deactivated, so it must be idempotent. fish treats *PATH variables as lists.
set -l _phlex_dir "$CONDA_PREFIX/lib"
if not contains -- $_phlex_dir $PHLEX_PLUGIN_PATH
    if string length -q -- $PHLEX_PLUGIN_PATH
        set -gx PHLEX_PLUGIN_PATH $_phlex_dir $PHLEX_PLUGIN_PATH
    else
        set -gx PHLEX_PLUGIN_PATH $_phlex_dir
    end
end
