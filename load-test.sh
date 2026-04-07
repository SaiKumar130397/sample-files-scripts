#!/bin/bash

BASE_URL="http://20.92.178.62"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

total=0
success=0
failed=0

# Shared counters via temp files (background processes can't share variables)
TMPDIR=$(mktemp -d)
echo 0 > "$TMPDIR/success"
echo 0 > "$TMPDIR/failed"
echo 0 > "$TMPDIR/total"

hit_post() {
  local url=$1
  local body=$2
  response=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$body" "$url")

  if [[ "$response" == "2"* ]]; then
    echo -e "${GREEN}[✓] POST $url $body → $response${NC}"
    echo $(($(cat "$TMPDIR/success") + 1)) > "$TMPDIR/success"
  else
    echo -e "${RED}[✗] POST $url $body → $response${NC}"
    echo $(($(cat "$TMPDIR/failed") + 1)) > "$TMPDIR/failed"
  fi
  echo $(($(cat "$TMPDIR/total") + 1)) > "$TMPDIR/total"
}

hit_get() {
  local url=$1
  response=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  if [[ "$response" == "2"* ]]; then
    echo -e "${GREEN}[✓] GET $url → $response${NC}"
    echo $(($(cat "$TMPDIR/success") + 1)) > "$TMPDIR/success"
  else
    echo -e "${RED}[✗] GET $url → $response${NC}"
    echo $(($(cat "$TMPDIR/failed") + 1)) > "$TMPDIR/failed"
  fi
  echo $(($(cat "$TMPDIR/total") + 1)) > "$TMPDIR/total"
}

PLANET_IDS=(1 2 3 4 5 6 7 8)
STARSHIP_IDS=(1 2 3 4 5 6 7 8)

CONCURRENCY=500   # number of parallel workers
DURATION=120     # run for 120 seconds
END_TIME=$((SECONDS + DURATION))

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Parallel Load Test — ${CONCURRENCY} workers      ${NC}"
echo -e "${YELLOW}   Duration: ${DURATION}s                    ${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${CYAN}Watch HPA in another terminal:${NC}"
echo -e "${CYAN}  watch -n 2 kubectl get hpa -n dev${NC}"
echo ""

round=0
while [ $SECONDS -lt $END_TIME ]; do
  round=$((round + 1))
  echo -e "${CYAN}--- Round $round (${SECONDS}s / ${DURATION}s) ---${NC}"

  # Launch CONCURRENCY parallel background requests
  for ((w=1; w<=CONCURRENCY; w++)); do
    # Randomly pick solar or starfleet
    if (( w % 2 == 0 )); then
      id=${PLANET_IDS[$((RANDOM % ${#PLANET_IDS[@]}))]}
      hit_post "$BASE_URL/solar/planet" "{\"id\": \"$id\"}" &
    else
      id=${STARSHIP_IDS[$((RANDOM % ${#STARSHIP_IDS[@]}))]}
      hit_post "$BASE_URL/starfleet/starship" "{\"id\": \"$id\"}" &
    fi
  done

  # Also fire base GETs in parallel
  hit_get "$BASE_URL/solar" &
  hit_get "$BASE_URL/starfleet" &

  # Wait for all background jobs to finish before next round
  wait

  sleep 0.1  # tiny pause between rounds
done

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "Total   : $(cat $TMPDIR/total)"
echo -e "${GREEN}Success : $(cat $TMPDIR/success)${NC}"
echo -e "${RED}Failed  : $(cat $TMPDIR/failed)${NC}"

rm -rf "$TMPDIR"