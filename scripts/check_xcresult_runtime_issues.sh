#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage:
  scripts/check_xcresult_runtime_issues.sh <path-to-xcresult>

Fails when the xcresult contains SwiftUI runtime issues that are actionable
for the app under test.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

XCRESULT_PATH="$1"
if [[ ! -d "$XCRESULT_PATH" ]]; then
    echo "xcresult bundle not found: $XCRESULT_PATH" >&2
    exit 2
fi

JSON_PATH="$(mktemp "${TMPDIR:-/tmp}/editor-xcresult-runtime-issues.XXXXXX.json")"
trap 'rm -f "$JSON_PATH"' EXIT

xcrun xcresulttool get --legacy --path "$XCRESULT_PATH" --format json >"$JSON_PATH"

issues="$(
    ruby -rjson -e '
      forbidden = [
        /Publishing changes from within view updates/,
        /Modifying state during view update/
      ]

      def walk(value, &block)
        yield value
        case value
        when Hash
          value.each_value { |child| walk(child, &block) }
        when Array
          value.each { |child| walk(child, &block) }
        end
      end

      data = JSON.parse(File.read(ARGV.fetch(0)))
      matches = []
      walk(data) do |node|
        next unless node.is_a?(Hash)
        message = node.dig("message", "_value")
        next unless message && forbidden.any? { |pattern| message.match?(pattern) }

        test_case = node.dig("testCaseName", "_value") || "unknown test"
        matches << "#{test_case}: #{message}"
      end

      puts matches.uniq.join("\n")
    ' "$JSON_PATH"
)"

if [[ -n "$issues" ]]; then
    echo "Forbidden runtime issues found in $XCRESULT_PATH:" >&2
    echo "$issues" >&2
    exit 1
fi

echo "No forbidden SwiftUI runtime issues found in $XCRESULT_PATH."
