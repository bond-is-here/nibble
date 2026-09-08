#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
nibble_report_checks=0
check_report() {
  if ! "$@"; then echo "UI report check failed: $*" >&2; exit 1; fi
  nibble_report_checks=$((nibble_report_checks + 1))
}

nibble_summary='{"passedTests":7,"failedTests":0,"skippedTests":0,"devicesAndConfigurations":[{"device":{"modelName":"iPhone Air","osVersion":"26.2"}}],"testFailures":[]}'
nibble_report=$(printf '%s' "$nibble_summary" | GITHUB_ACTIONS=true bash Tools/report-ui-results.sh)
check_report test "$nibble_report" = '::notice title=Nibble UI result::7 passed, 0 failed, 0 skipped · iPhone Air / iOS 26.2'
nibble_report=$(printf '%s' "$nibble_summary" | GITHUB_ACTIONS=false bash Tools/report-ui-results.sh)
check_report test "$nibble_report" = 'Nibble UI: 7 passed, 0 failed, 0 skipped · iPhone Air / iOS 26.2'

nibble_report=$(printf '%s' '{"testFailures":[{"testIdentifierString":"Test/manualDraft()","failureText":"one%\n::error::injected\rline"}]}' | GITHUB_ACTIONS=true bash Tools/report-ui-results.sh)
check_report test "$(printf '%s\n' "$nibble_report" | wc -l | tr -d ' ')" = 2
check_report test "${nibble_report##*$'\n'}" = '::error title=Nibble UI failure::Test/manualDraft(): one%25%0A::error::injected%0Dline'
check_report test "${nibble_report%%$'\n'*}" = '::notice title=Nibble UI result::unknown passed, unknown failed, unknown skipped · '
if printf '%s' 'not json' | bash Tools/report-ui-results.sh >/dev/null 2>&1; then
  echo "Malformed test summaries must not appear successful." >&2; exit 1
fi
nibble_report_checks=$((nibble_report_checks + 1))
echo "Passed $nibble_report_checks UI result-reporting checks."
