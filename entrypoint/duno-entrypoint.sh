#!/bin/sh
# DUNO entrypoint: resolve Railway-friendly runtime settings,
# then hand over to the Selkies base entrypoint (s6 supervision).
# POSIX sh (runs under /bin/sh).
set -eu

# Railway injects PORT (the internal port its proxy targets) and it can
# change between deploys. Selkies listens on SELKIES_PORT, so map it when
# the operator did not set one explicitly. Local default: 8080.
if [ -z "${SELKIES_PORT:-}" ]; then
  if [ -n "${PORT:-}" ]; then
    export SELKIES_PORT="${PORT}"
  else
    export SELKIES_PORT="8080"
  fi
fi

exec /etc/container-entrypoint.sh "$@"
