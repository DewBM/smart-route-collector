#!/usr/bin/env bash
# Glassline backend smoke test.
#
# Exercises the REST API end to end against a running backend and prints a
# pass/fail table. It CHANGES today's trip (collects and skips stops), so run it
# against a demo/test database, and reset today's trip before running it again:
#   Seed__ResetToday=true dotnet run
#
# Usage: docs/testing/api-smoke-test.sh [base-url]      (default http://localhost:5081)
# Needs: curl, python3. Exit code is the number of failed checks.

API="${1:-http://localhost:5081}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0
FAIL=0

# --- helpers ---------------------------------------------------------------
check() { # name expected actual
  if [ "$2" == "$3" ]; then
    printf "  PASS  %-62s %s\n" "$1" "$3"; PASS=$((PASS + 1))
  else
    printf "  FAIL  %-62s expected [%s] got [%s]\n" "$1" "$2" "$3"; FAIL=$((FAIL + 1))
  fi
}
check_in() { # name "a|b" actual  (actual must be one of the alternatives)
  if [[ "|$2|" == *"|$3|"* ]]; then
    printf "  PASS  %-62s %s\n" "$1" "$3"; PASS=$((PASS + 1))
  else
    printf "  FAIL  %-62s expected one of [%s] got [%s]\n" "$1" "$2" "$3"; FAIL=$((FAIL + 1))
  fi
}
code() { curl -s -o "$TMP/body" -w '%{http_code}' "$@"; }
json() { python3 -c "import sys,json; d=json.load(open('$TMP/body')); print($1)"; }
post() { # path json
  code -X POST "$API$1" -H 'Content-Type: application/json' -d "$2"
}
trip() { curl -s "$API/api/trips/today" > "$TMP/trip.json"; }
tj() { python3 -c "import json; t=json.load(open('$TMP/trip.json')); print($1)"; }

# 1x1 PNG, and a payload that is not an image
base64 -d > "$TMP/pixel.png" <<< "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
echo "not an image" > "$TMP/note.txt"
head -c 4000000 /dev/zero > "$TMP/big.jpg"

echo "Glassline API smoke test against $API"
echo

# --- 1. today's trip --------------------------------------------------------
echo "Trip"
check "GET /api/trips/today returns 200" 200 "$(code "$API/api/trips/today")"
trip
TRIP=$(tj "t['tripId']")
STOPS=$(tj "len(t['stops'])")
check "trip has stops" True "$([ "$STOPS" -ge 4 ] && echo True || echo False)"
check "exactly one stop is Next" 1 "$(tj "sum(1 for s in t['stops'] if s['status']=='Next')")"
check "stops are in stopOrder 1..n" True "$(tj "[s['stopOrder'] for s in t['stops']]==list(range(1,len(t['stops'])+1))")"
check "same trip returned on a second call" "$TRIP" "$(curl -s "$API/api/trips/today" | python3 -c 'import sys,json;print(json.load(sys.stdin)["tripId"])')"
check "stops carry contact details" True "$(tj "all(s.get('phone') for s in t['stops'])")"

# pick stops: A = Next, B = a later Pending, C = another Pending, D = another
mapfile -t IDS < <(tj "'\n'.join(str(s['supplierId']) for s in t['stops'] if s['status'] in ('Next','Pending'))")
A=${IDS[0]}; B=${IDS[2]}; C=${IDS[1]}; D=${IDS[3]}

# --- 2. collections ---------------------------------------------------------
echo; echo "Collections"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
col() { echo "{\"tripId\":$TRIP,\"supplierId\":$1,\"clearKg\":$2,\"colouredKg\":$3,\"condition\":\"Clean\",\"collectedAt\":\"$NOW\"}"; }
check "collect the Next stop" 200 "$(post /api/collections "$(col "$A" 1 1)")"
trip
check "  that stop is now Collected" Collected "$(tj "[s['status'] for s in t['stops'] if s['supplierId']==$A][0]")"
check "  exactly one Next remains" 1 "$(tj "sum(1 for s in t['stops'] if s['status']=='Next')")"
check "repeat the same collection (idempotent)" 200 "$(post /api/collections "$(col "$A" 1 1)")"
check "  message says already recorded" "Collection already recorded." "$(json "d['message']")"
check "collection for an unknown supplier" 404 "$(post /api/collections "$(col 99999 1 1)")"
check "collect a later, non-Next stop (offline order)" 200 "$(post /api/collections "$(col "$B" 9999 9999)")"
trip
check "  it is Collected and one Next still exists" "Collected 1" "$(tj "[s['status'] for s in t['stops'] if s['supplierId']==$B][0]") $(tj "sum(1 for s in t['stops'] if s['status']=='Next')")"

# --- 3. skip ---------------------------------------------------------------
echo; echo "Skip stop"
NEXT=$(tj "[s['supplierId'] for s in t['stops'] if s['status']=='Next'][0]")
check "skip the Next stop" 200 "$(post "/api/trips/$TRIP/stops/$NEXT/skip" '{"reason":"Supplier closed"}')"
check "  response marks it Skipped with the reason" "Skipped|Supplier closed" "$(json "[(s['status']+'|'+(s['skipReason'] or '')) for s in d['stops'] if s['supplierId']==$NEXT][0]")"
check "  exactly one Next in the new route" 1 "$(json "sum(1 for s in d['stops'] if s['status']=='Next')")"
check "  stop orders stay unique 1..n" True "$(json "sorted(s['stopOrder'] for s in d['stops'])==list(range(1,len(d['stops'])+1))")"
check "skip again (idempotent)" 200 "$(post "/api/trips/$TRIP/stops/$NEXT/skip" '{"reason":"Supplier closed"}')"
check "skip an already collected stop" 400 "$(post "/api/trips/$TRIP/stops/$A/skip" '{"reason":"Other"}')"
check "skip without a reason" 400 "$(post "/api/trips/$TRIP/stops/$C/skip" '{"reason":""}')"
check "skip on an unknown stop" 404 "$(post "/api/trips/$TRIP/stops/99999/skip" '{"reason":"Other"}')"
check "collection for a skipped stop is refused" 400 "$(post /api/collections "$(col "$NEXT" 1 1)")"

# --- 4. attachments ---------------------------------------------------------
echo; echo "Photo and signature"
check "photo for a stop without a collection" 404 "$(code -F tripId=$TRIP -F supplierId=$C -F "file=@$TMP/pixel.png;type=image/png" "$API/api/collections/photo")"
check "upload a photo" 200 "$(code -F tripId=$TRIP -F supplierId=$A -F "file=@$TMP/pixel.png;type=image/png" "$API/api/collections/photo")"
check "upload a photo again (replaces)" 200 "$(code -F tripId=$TRIP -F supplierId=$A -F "file=@$TMP/pixel.png;type=image/png" "$API/api/collections/photo")"
check "download the photo" "200 image/png" "$(curl -s -o /dev/null -w '%{http_code} %{content_type}' "$API/api/collections/photo/$TRIP/$A")"
check "photo that is not an image is refused" 400 "$(code -F tripId=$TRIP -F supplierId=$A -F "file=@$TMP/note.txt;type=text/plain" "$API/api/collections/photo")"
check_in "photo over 3 MB is refused" "400|413" "$(code -F tripId=$TRIP -F supplierId=$A -F "file=@$TMP/big.jpg;type=image/jpeg" "$API/api/collections/photo")"
check "no photo for a stop that has none" 404 "$(code "$API/api/collections/photo/$TRIP/$B")"
check "upload a signature (PNG)" 200 "$(code -F tripId=$TRIP -F supplierId=$A -F signerName=N.Perera -F "file=@$TMP/pixel.png;type=image/png" "$API/api/collections/signature")"
check "signature must be a PNG" 400 "$(code -F tripId=$TRIP -F supplierId=$A -F "file=@$TMP/pixel.png;type=image/jpeg" "$API/api/collections/signature")"
check "download the signature" 200 "$(code "$API/api/collections/signature/$TRIP/$A")"

# --- 5. reports -------------------------------------------------------------
echo; echo "Reports"
check "trip summary" 200 "$(code "$API/api/trips/$TRIP/summary")"
check "  photo and signature are linked" "True True N.Perera" "$(json "[(bool(s['photoUrl']),bool(s['signatureUrl']),s['signedBy']) for s in d['stops'] if s['photoUrl']][0]" | tr -d "(),'" )"
check "  skipped stop is not a shortfall" "True False" "$(json "[(s['skipped'],s['belowExpected']) for s in d['stops'] if s['skipped']][0]" | tr -d "(),")"
check "  pending stops are not shortfalls" 0 "$(json "sum(1 for s in d['stops'] if s['status'] in ('Pending','Next') and s['belowExpected'])")"
check "  the over-delivered stop is on target" False "$(json "[s['belowExpected'] for s in d['stops'] if s['collectedClearKg']==9999][0]")"
check "unknown trip summary" 404 "$(code "$API/api/trips/999999/summary")"
check "history" 200 "$(code "$API/api/trips/history")"
check "  includes today with a skipped stop" True "$(json "any(h['tripId']==$TRIP and h['skippedCount']>=1 for h in d)")"
check "  today is in progress, not complete" False "$(json "[h['isComplete'] for h in d if h['tripId']==$TRIP][0]")"
check "insights (7 days)" 7 "$(curl -s "$API/api/insights?days=7" | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["daily"]))')"
check "insights days are clamped to 90" 90 "$(curl -s "$API/api/insights?days=500" | python3 -c 'import sys,json;print(len(json.load(sys.stdin)["daily"]))')"
check "supplier detail" 200 "$(code "$API/api/suppliers/$A")"
check "  shows at most 3 recent collections" True "$(json "len(d['recentCollections'])<=3")"
check "unknown supplier" 404 "$(code "$API/api/suppliers/99999")"
check "update supplier contact" 200 "$(code -X PUT "$API/api/suppliers/$A/contact" -H 'Content-Type: application/json' -d '{"phone":"+94 77 555 9999","notes":"Smoke test"}')"
check "  change is visible" "+94 77 555 9999" "$(curl -s "$API/api/suppliers/$A" | python3 -c 'import sys,json;print(json.load(sys.stdin)["phone"])')"

# --- 6. final sync completes the trip ---------------------------------------
echo; echo "Final sync"
trip
mapfile -t LEFT < <(tj "'\n'.join(str(s['supplierId']) for s in t['stops'] if s['status'] in ('Next','Pending'))")
ITEMS=""
for id in "${LEFT[@]}"; do ITEMS="$ITEMS{\"tripId\":$TRIP,\"supplierId\":$id,\"clearKg\":10,\"colouredKg\":10,\"condition\":\"Clean\",\"collectedAt\":\"$NOW\"},"; done
check "sync the remaining collections" 200 "$(post /api/collections/sync "{\"tripId\":$TRIP,\"collections\":[${ITEMS%,}]}")"
trip
check "  every stop is now Collected or Skipped" True "$(tj "all(s['status'] in ('Collected','Skipped') for s in t['stops'])")"
check "  no stop is left as Next" 0 "$(tj "sum(1 for s in t['stops'] if s['status']=='Next')")"
check "sync again (idempotent)" 200 "$(post /api/collections/sync "{\"tripId\":$TRIP,\"collections\":[${ITEMS%,}]}")"
curl -s "$API/api/trips/history" > "$TMP/body"
check "history now reports today as complete" True "$(json "[h['isComplete'] for h in d if h['tripId']==$TRIP][0]")"

echo
echo "Result: $PASS passed, $FAIL failed"
exit "$FAIL"
