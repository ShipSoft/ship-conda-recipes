#!/bin/sh
# Remove this environment's lib directory from PHLEX_PLUGIN_PATH and unset the
# variable if nothing else is left in it.
if [ -n "${PHLEX_PLUGIN_PATH+x}" ]; then
  _phlex_dir="${CONDA_PREFIX}/lib"
  _phlex_path=":${PHLEX_PLUGIN_PATH}:"
  while :; do
    case "${_phlex_path}" in
      *":${_phlex_dir}:"*)
        _phlex_path="${_phlex_path%%:"${_phlex_dir}":*}:${_phlex_path#*:"${_phlex_dir}":}" ;;
      *) break ;;
    esac
  done
  _phlex_path="${_phlex_path#:}"
  _phlex_path="${_phlex_path%:}"
  if [ -n "${_phlex_path}" ]; then
    export PHLEX_PLUGIN_PATH="${_phlex_path}"
  else
    unset PHLEX_PLUGIN_PATH
  fi
  unset _phlex_dir _phlex_path
fi
