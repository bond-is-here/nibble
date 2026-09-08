#!/bin/bash
set -euo pipefail

# Read xcresulttool's exported summary, not the much larger raw test log.
# Annotation messages are escaped so a test string cannot inject workflow commands.
jq -r --arg actions "${GITHUB_ACTIONS:-false}" '
  def escaped: gsub("%"; "%25") | gsub("\r"; "%0D") | gsub("\n"; "%0A");
  def summary:
    "\(.passedTests // "unknown") passed, \(.failedTests // "unknown") failed, \(.skippedTests // "unknown") skipped"
    + " · " + ([.devicesAndConfigurations[]?.device | "\(.modelName // .deviceName // "Unknown device") / iOS \(.osVersion // "unknown")"] | join(", "));
  (summary | if $actions == "true" then "::notice title=Nibble UI result::" + escaped else "Nibble UI: " + . end),
  ((.testFailures // [])[0:10][] |
    "\(.testIdentifierString // .testName // "Unknown test"): \(.failureText // "No failure detail exported")" | .[0:16000] |
    if $actions == "true" then "::error title=Nibble UI failure::" + escaped else "FAIL: " + escaped end)
' "${1:--}"
