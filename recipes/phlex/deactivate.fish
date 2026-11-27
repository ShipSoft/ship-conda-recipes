# Remove this environment's lib directory from PHLEX_PLUGIN_PATH and erase the
# variable if nothing else is left in it.
if set -q PHLEX_PLUGIN_PATH
    set -l _phlex_dir "$CONDA_PREFIX/lib"
    while set -l _phlex_i (contains -i -- $_phlex_dir $PHLEX_PLUGIN_PATH)
        set -e PHLEX_PLUGIN_PATH[$_phlex_i]
    end
    if not string length -q -- $PHLEX_PLUGIN_PATH
        set -e PHLEX_PLUGIN_PATH
    end
end
