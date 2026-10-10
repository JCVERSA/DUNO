#!/bin/sh
# Functional test for entrypoint/duno-entrypoint.sh.
#
# Run with BOTH shells (the entrypoint ships as #!/bin/sh but must stay
# sourceable under bash too):
#   sh   tests/test-entrypoint.sh
#   bash tests/test-entrypoint.sh
#
# Exits non-zero if any check fails. The entrypoint is sourced with
# DUNO_SOURCED=true so only its functions get defined: the test exercises the
# real duno_sanitize_env / duno_resolve_port, not a copy of them.

fail=0
check() {
  _desc=$1; shift
  if eval "$@"; then echo "PASS: ${_desc}"; else echo "FAIL: ${_desc}"; fail=1; fi
  unset _desc
}

# Resolve the repo root from this file's own location, so the test runs from
# anywhere (no hardcoded checkout path).
_duno_here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
_duno_root=$(CDPATH= cd -- "${_duno_here}/.." && pwd) || exit 1

# Sentinels for the "no command substitution was executed" checks: clear any
# stale copy from an earlier run so a pass means what it says.
rm -f /tmp/DUNO_PWNED /tmp/DUNO_PWNED2

DUNO_SOURCED=true
. "${_duno_root}/entrypoint/duno-entrypoint.sh"

# Hostile environment, modeled on what Railway injects (git metadata).
export RAILWAY_GIT_COMMIT_MESSAGE='Replace TigerVNC/noVNC with Selkies

- Dockerfile: FROM selkies/base (Ubuntu 26.04) + XFCE + Firefox (Mozilla APT repo)'
export RAILWAY_GIT_AUTHOR='arena-agent <297053741+arena-agent@users.noreply.github.com>'
export WEIRD_PARENS='foo (bar)'
export WEIRD_DOLLAR='a$(touch /tmp/DUNO_PWNED)b'
export WEIRD_BACKTICK='a`touch /tmp/DUNO_PWNED2`b'
export WEIRD_SEMI='a;b'
export WEIRD_SPACE='hello world'
export GOOD_TOKEN='hello-world_1.2:/+@%=,'
export PORT='8080'
export SELKIES_PORT=''
export PASSWD='abc123'
export LD_PRELOAD='/usr/lib/x.so:/opt/a-b_c.so'
export EMPTY_OK=''
export A='single-letter-name-ok'

duno_sanitize_env

check "multiline commit message dropped" '[ -z "${RAILWAY_GIT_COMMIT_MESSAGE+x}" ]'
check "author with <> dropped" '[ -z "${RAILWAY_GIT_AUTHOR+x}" ]'
check "parens value dropped" '[ -z "${WEIRD_PARENS+x}" ]'
check "dollar value dropped" '[ -z "${WEIRD_DOLLAR+x}" ]'
check "backtick value dropped" '[ -z "${WEIRD_BACKTICK+x}" ]'
check "semicolon value dropped" '[ -z "${WEIRD_SEMI+x}" ]'
check "space value dropped" '[ -z "${WEIRD_SPACE+x}" ]'
check "good token kept" '[ "${GOOD_TOKEN}" = "hello-world_1.2:/+@%=," ]'
check "PORT kept" '[ "${PORT}" = "8080" ]'
check "PASSWD kept" '[ "${PASSWD}" = "abc123" ]'
check "LD_PRELOAD kept" '[ "${LD_PRELOAD}" = "/usr/lib/x.so:/opt/a-b_c.so" ]'
check "empty value kept" '[ -n "${EMPTY_OK+x}" ]'
check "single-letter name kept" '[ "${A}" = "single-letter-name-ok" ]'
check "no command substitution executed (dollar)" '[ ! -e /tmp/DUNO_PWNED ]'
check "no command substitution executed (backtick)" '[ ! -e /tmp/DUNO_PWNED2 ]'

unset SELKIES_PORT; PORT='17712'; duno_resolve_port
check "PORT mapped to SELKIES_PORT" '[ "${SELKIES_PORT}" = "17712" ]'
SELKIES_PORT='9999'; PORT='17712'; duno_resolve_port
check "explicit SELKIES_PORT wins" '[ "${SELKIES_PORT}" = "9999" ]'
unset SELKIES_PORT; unset PORT; duno_resolve_port
check "default 8080" '[ "${SELKIES_PORT}" = "8080" ]'

# After sanitizing, every remaining env line must be serializer-safe:
# NAME=plain (single line, conservative charset).
duno_sanitize_env
BAD=$(env | grep -Ev '^[A-Za-z_][A-Za-z0-9_]*=[A-Za-z0-9_.,:/+@%=-]*$' | head -5)
check "remaining env is serializer-safe" '[ -z "$BAD" ]'
[ -n "$BAD" ] && { echo "--- offending lines:"; echo "$BAD"; }

echo "-----------------------------------------"
if [ "$fail" -eq 0 ]; then
  echo "19/19 checks PASS"
else
  echo "RESULT: FAILURES (see above)"
fi
exit $fail
