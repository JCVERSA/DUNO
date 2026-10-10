#!/bin/sh
# DUNO entrypoint: sanitize the environment for the Selkies base entrypoint,
# resolve Railway-friendly runtime settings, then hand over to s6 supervision.
# POSIX sh (runs under /bin/sh). When sourced with DUNO_SOURCED=true (tests),
# only the functions below are defined.
set -eu

# Drop env vars the Selkies base entrypoint cannot serialize into
# ${XDG_RUNTIME_DIR}/container-env: it writes one `export NAME=value` line per
# variable, so a multiline value (Railway injects the git commit message!) or
# shell-active characters corrupt the file and every service sourcing it fails
# with `export: ...: not a valid identifier` / `syntax error near (` — the
# selkies server itself never starts and the port stays closed. None of the
# dropped metadata is needed inside the session. A value is kept only when it
# uses a conservative charset (plain tokens and paths, no spaces/newlines).
duno_sanitize_env() {
  set -f # no pathname expansion on hostile fragments below
  for _duno_name in $(env | cut -d= -f1); do
    # NOTE: glob `*` is not a quantifier, so "all chars in class" is tested
    # by exclusion: an identifier holds no char outside [A-Za-z0-9_].
    case "${_duno_name}" in
      [A-Za-z_]*)
        case "${_duno_name}" in
          *[!A-Za-z0-9_]*)
            # Fragment of a multiline value (its NAME= line is visited — and
            # dropped — separately). Nothing addressable to remove.
            :
            ;;
          *)
            # Valid identifier. Inner double quotes below: the value must be
            # assigned literally, never re-parsed as shell code (it can hold
            # newlines, parens, $(...)).
            eval "_duno_value=\"\${${_duno_name}-}\""
            case "${_duno_value}" in
              *[!A-Za-z0-9_.,:/+@%=-]*)
                unset "${_duno_name}"
                ;;
            esac
            unset _duno_value
            ;;
        esac
        ;;
      *)
        # Empty, digit-start, or other non-identifier (multiline fragment).
        # The shell cannot address such a name anyway. Nothing to do.
        :
        ;;
    esac
  done
  unset _duno_name
  set +f
  return 0
}

# Railway injects PORT (the internal port its proxy targets) and it can
# change between deploys. Selkies listens on SELKIES_PORT, so map it when
# the operator did not set one explicitly. Local default: 8080.
duno_resolve_port() {
  if [ -z "${SELKIES_PORT:-}" ]; then
    if [ -n "${PORT:-}" ]; then
      SELKIES_PORT="${PORT}"
    else
      SELKIES_PORT="8080"
    fi
    export SELKIES_PORT
  fi
  return 0
}

if [ "${DUNO_SOURCED:-}" = "true" ]; then
  return 0 2>/dev/null || true
fi

duno_sanitize_env
duno_resolve_port
echo "duno: selkies will listen on port ${SELKIES_PORT} (PORT=${PORT:-unset})"
exec /etc/container-entrypoint.sh "$@"
