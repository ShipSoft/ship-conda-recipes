#!/bin/sh
# Prepend this environment's lib directory to PHLEX_PLUGIN_PATH unless it is
# already listed. conda re-runs this script when a stacked environment is
# deactivated, so it must be idempotent.
_phlex_dir="${CONDA_PREFIX}/lib"
case ":${PHLEX_PLUGIN_PATH-}:" in
  *":${_phlex_dir}:"*) ;;
  *) export PHLEX_PLUGIN_PATH="${_phlex_dir}${PHLEX_PLUGIN_PATH:+:${PHLEX_PLUGIN_PATH}}" ;;
esac
unset _phlex_dir
