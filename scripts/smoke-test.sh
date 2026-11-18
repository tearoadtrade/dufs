#!/bin/sh
# Smoke test for a dufs deployment.
#
# Usage:
#   ./scripts/smoke-test.sh <base-url> <user:password>
# or with environment variables:
#   DUFS_URL=<base-url> DUFS_AUTH=<user:password> ./scripts/smoke-test.sh
#
# Checks, in order: unauthenticated GET -> 401, authenticated GET -> 200,
# upload a small file -> 201, download matches the uploaded content,
# delete -> 204. Exits non-zero and names the step that failed.
# No real address or password is hardcoded here; pass them as arguments.
set -u

BASE_URL="${1:-${DUFS_URL:-}}"
AUTH="${2:-${DUFS_AUTH:-}}"

if [ -z "$BASE_URL" ] || [ -z "$AUTH" ]; then
    echo "usage: $0 <base-url> <user:password>" >&2
    echo "   or: DUFS_URL=<base-url> DUFS_AUTH=<user:password> $0" >&2
    exit 2
fi

# Strip a trailing slash so URL joins are predictable.
BASE_URL="${BASE_URL%/}"

TMP_FILE="$(mktemp)"
printf 'dufs-smoke-test\n' > "$TMP_FILE"
REMOTE_NAME="dufs-smoke-test-$(date +%s).txt"
REMOTE_URL="$BASE_URL/$REMOTE_NAME"

cleanup() {
    rm -f "$TMP_FILE"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $1" >&2
    # Best effort: remove the remote file if the upload succeeded.
    curl -s -o /dev/null -u "$AUTH" -X DELETE "$REMOTE_URL" 2>/dev/null
    exit 1
}

code() {
    # $1 = curl args... ; prints the HTTP status code
    curl -s -o /dev/null -w '%{http_code}' "$@"
}

echo "== dufs smoke test: $BASE_URL"

# 1. Unauthenticated GET must be rejected with 401.
STATUS=$(code "$BASE_URL/")
[ "$STATUS" = "401" ] || fail "step 1 (unauthenticated GET): expected 401, got $STATUS"
echo "ok: unauthenticated GET -> 401"

# 2. Authenticated GET must succeed with 200.
STATUS=$(code -u "$AUTH" "$BASE_URL/")
[ "$STATUS" = "200" ] || fail "step 2 (authenticated GET): expected 200, got $STATUS"
echo "ok: authenticated GET -> 200"

# 3. Upload a small file must return 201.
STATUS=$(code -u "$AUTH" -T "$TMP_FILE" "$REMOTE_URL")
[ "$STATUS" = "201" ] || fail "step 3 (upload): expected 201, got $STATUS"
echo "ok: upload -> 201"

# 4. Download must return the uploaded content.
DOWNLOADED="$(curl -s -u "$AUTH" "$REMOTE_URL")"
[ "$DOWNLOADED" = "dufs-smoke-test" ] || fail "step 4 (download): content mismatch (got: $DOWNLOADED)"
echo "ok: download content matches"

# 5. Delete must return 204.
STATUS=$(code -u "$AUTH" -X DELETE "$REMOTE_URL")
[ "$STATUS" = "204" ] || fail "step 5 (delete): expected 204, got $STATUS"
echo "ok: delete -> 204"

echo "== all smoke tests passed"
exit 0
