# Shared assertion helpers for the zsh smoke suites. Source after re-exec'ing
# under `zsh -f`; call `summary` last — it exits 1 when anything failed.
#
#   ok  <desc> <expected> <actual>      exact match
#   okm <desc> <glob-pattern> <actual>  pattern match (^pat negates)

typeset -gi PASS=0 FAIL=0

function ok() {
  if [[ $2 == $3 ]]; then
    (( ++PASS )); print -r -- "ok   - $1"
  else
    (( ++FAIL )); print -r -- "FAIL - $1"
    print -r -- "       expected: ${(qqqq)2}"
    print -r -- "       actual:   ${(qqqq)3}"
  fi
}

function okm() {
  local negate= pat=$2
  [[ $pat == '^'* ]] && { negate=1; pat=${pat#^}; }
  if [[ -z $negate && $3 == ${~pat} || -n $negate && $3 != ${~pat} ]]; then
    (( ++PASS )); print -r -- "ok   - $1"
  else
    (( ++FAIL )); print -r -- "FAIL - $1"
    print -r -- "       pattern:  ${(qqqq)2}"
    print -r -- "       actual:   ${(qqqq)3}"
  fi
}

function summary() {
  print -r -- "----"
  print -r -- "pass: $PASS  fail: $FAIL"
  (( FAIL == 0 )) || exit 1
}
