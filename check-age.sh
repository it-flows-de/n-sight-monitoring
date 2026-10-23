#!/usr/bin/env bash
# check-age.sh - n-sight check: FAIL if a file is older than N calendar days.
# Author:     flo.alt@it-flows.de
# Version:    1.0.0
# Parameters: --path /full/path/to/file [--days N]
#             --days default is 1 (a file from yesterday is OK, from today is age 0)
# Exit:       0 = OK, 100 = FAIL. Output is ASCII only and shown in the dashboard.

# Fixed locale: tool messages are English and ASCII, independent of the server.
# Dates are always printed explicitly as YYYY-MM-DD HH:MM:SS (see date calls).
export LC_ALL=C

EXIT_OK=0
EXIT_FAIL=100
DEFAULT_DAYS=1
USAGE="Parameters: --path /full/path/to/file [--days N]"

# Output is buffered so the headline can be printed first.
HEADLINE=""   # first output line, shown in the dashboard overview
DETAILS=""    # all lines between headline and RESULT line

# Replace every non-printable or non-ASCII byte with "?" before printing
safe() {
    printf '%s' "$1" | tr -c '[:print:]' '?'
}

# Add one line to the detail output
detail() {
    DETAILS+="$1"$'\n'
}

# Print the buffered output and end the check.
# Order: headline, details, blank line, RESULT line, blank line, closing line.
# Arguments: exit code, label (OK or FAIL), result text.
finish() {
    local code="$1" label="$2" text="$3" closing
    if [ "${code}" -eq "${EXIT_OK}" ]; then
        closing="Yeah, looks fantastic. Everything flows."
    else
        closing="Oh shit, what a mess!"
    fi
    printf '%s\n' "${HEADLINE:-${text}}"
    printf '%s' "${DETAILS}"
    printf '\nRESULT: %s - %s\n' "${label}" "${text}"
    printf '\n%s\n' "${closing}"
    exit "${code}"
}

# End the check with OK
ok() {
    finish "${EXIT_OK}" "OK" "$1"
}

# End the check with FAIL
fail() {
    finish "${EXIT_FAIL}" "FAIL" "$1"
}

# Same as fail(), but also shows the expected command line
fail_usage() {
    detail "${USAGE}"
    fail "$1"
}

# Convert epoch seconds to a calendar day number (local date, DST-safe)
day_number() {
    local d
    d="$(date -d "@$1" '+%Y-%m-%d')" || return 1
    echo $(( $(date -u -d "${d} 00:00:00" '+%s') / 86400 ))
}

# --- Parameters ---
path=""
days="${DEFAULT_DAYS}"
while [ $# -gt 0 ]; do
    case "$1" in
        --path)
            [ $# -ge 2 ] || fail_usage "Option --path needs a value"
            path="$2"; shift 2 ;;
        --days)
            [ $# -ge 2 ] || fail_usage "Option --days needs a value"
            days="$2"; shift 2 ;;
        *)
            fail_usage "Unknown parameter: $(safe "$1")" ;;
    esac
done

[ -n "${path}" ] || fail_usage "Parameter --path is missing"
[[ "${days}" =~ ^[0-9]+$ ]] || fail_usage "Parameter --days must be a whole number >= 0"

shown_path="$(safe "${path}")"
detail "CHECK: file age"
detail "Path: ${shown_path}"
detail "Max age allowed: ${days} day(s)"

# --- Checks on the file ---
[ -e "${path}" ] || fail "File does not exist: ${shown_path}"
[ -f "${path}" ] || fail "Path is not a regular file: ${shown_path}"
[ -r "${path}" ] || fail "File is not readable: ${shown_path}"

mtime="$(stat -c '%Y' -- "${path}")" || fail "Cannot read modification time: ${shown_path}"
now="$(date '+%s')"
mtime_text="$(date -d "@${mtime}" '+%Y-%m-%d %H:%M:%S')"
detail "Last modified: ${mtime_text}"

age=$(( $(day_number "${now}") - $(day_number "${mtime}") ))
detail "Age: ${age} day(s)"

# --- Result ---
if [ "${age}" -lt 0 ]; then
    HEADLINE="Last modified: ${mtime_text} (in the future)"
    fail "Modification date is in the future (check the server clock)"
fi

HEADLINE="Last modified: ${mtime_text} (${age} day(s) old, max ${days})"
[ "${age}" -le "${days}" ] || fail "File is ${age} day(s) old, allowed are ${days}"

ok "File is ${age} day(s) old, allowed are ${days}"
