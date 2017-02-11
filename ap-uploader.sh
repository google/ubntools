#!/bin/sh
# Run on the access point:
#   while true; do ./ap-uploader.sh user@hostname:/path/to/dir; sleep 600;done
set -e
DST="$1"
FN="ap-mca-dump-$(date +%s).json.gz"
TMPF="$(mktemp)"
trap "rm -f \"${TMPF}\"" EXIT
mca-dump | gzip -9 > "${TMPF}"
scp "${TMPF}" "${DST}/${FN}"
