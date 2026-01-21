#!/bin/bash

DOMAINS="domains.txt"
OUTDIR="bounty-results"
KEYWORDS="responsible|disclosure|security.txt|bug|bounty|reward|hall.of.fame|white.hat"
GAU="$HOME/go/bin/gau"


TOTAL_DOMAINS=$(wc -l < "$DOMAINS")
PROGRESS_DIR="$OUTDIR/progress"
mkdir -p "$PROGRESS_DIR"
rm -f "$PROGRESS_DIR"/*.done
export PROGRESS_DIR TOTAL_DOMAINS

mkdir -p "$OUTDIR"

# =========================
# PARALLEL ARCHIVE DISCOVERY
# =========================

process_domain() {
  d="$1"
  safe_d=$(echo "$d" | tr '/:' '_')

  gau "$d" 2>/dev/null \
    | grep -Ei "$KEYWORDS" \
    | sed "s#^#[$d] #" \
    >> "$OUTDIR/raw_hits_$safe_d.txt"

  touch "$PROGRESS_DIR/$safe_d.done"
}


export -f process_domain
export KEYWORDS OUTDIR PROGRESS_DIR

progress_domains() {
  while true; do
    DONE=$(ls "$PROGRESS_DIR" 2>/dev/null | wc -l)
    PERCENT=$(( DONE * 100 / TOTAL_DOMAINS ))

    printf "\r[+] Domain scan progress: %d/%d (%d%%)" \
      "$DONE" "$TOTAL_DOMAINS" "$PERCENT"

    if [ "$DONE" -ge "$TOTAL_DOMAINS" ]; then
      echo
      break
    fi

    sleep 1
  done
}


echo "[+] Scanning domains in parallel..."

progress_domains &     # 👈 START progress
PB_PID=$!

cat "$DOMAINS" \
 | xargs -P 10 -I {} bash -c 'process_domain "$@"' _ {}

wait                   # wait for workers
kill "$PB_PID" 2>/dev/null

cat "$OUTDIR"/raw_hits_*.txt > "$OUTDIR/raw_hits.txt"
rm "$OUTDIR"/raw_hits_*.txt


# 2️⃣ Deduplicate
sort -u "$OUTDIR/raw_hits.txt" > "$OUTDIR/unique_hits.txt"

echo "[+] Extracting URLs for live validation..."

# 3️⃣ Extract only URLs
awk '{print $2}' "$OUTDIR/unique_hits.txt" > "$OUTDIR/urls_only.txt"

echo "[+] Checking which pages are LIVE..."

# 4️⃣ LIVE validation (REAL pages only)
$HTTPX -l "$OUTDIR/urls_only.txt" \
  -silent \
  -mc 200,301,302 \
  -follow-redirects \
  -title \
  -status-code \
  -o "$OUTDIR/live_bounty_pages.txt"


echo "[✓] LIVE bounty pages collected"

# ============================
# ⬇️ ADD CLASSIFICATION HERE ⬇️
# ============================

echo "[+] Classifying bounty programs..."

PAID="$OUTDIR/paid.txt"
SWAG="$OUTDIR/swag.txt"
HOF="$OUTDIR/hall_of_fame.txt"
UNKNOWN="$OUTDIR/unknown.txt"

> "$PAID"
> "$SWAG"
> "$HOF"
> "$UNKNOWN"

TOTAL_URLS=$(wc -l < "$OUTDIR/live_bounty_pages.txt")
COUNT=0

while read -r line; do
  COUNT=$((COUNT + 1))
  printf "\r[+] Classifying: %d/%d" "$COUNT" "$TOTAL_URLS"

  url=$(echo "$line" | awk '{print $1}')

  body=$(curl -Ls --max-time 10 "$url" | tr 'A-Z' 'a-z')

  if echo "$body" | grep -Eq "reward|bounty|paid|\$|usd|cash|compensation"; then
    echo "$url" >> "$PAID"

  elif echo "$body" | grep -Eq "swag|tshirt|t-shirt|hoodie|sticker|gift"; then
    echo "$url" >> "$SWAG"

  elif echo "$body" | grep -Eq "hall of fame|hof|recognition|thanks"; then
    echo "$url" >> "$HOF"

  else
    echo "$url" >> "$UNKNOWN"
  fi

done < "$OUTDIR/live_bounty_pages.txt"

echo "[✓] Classification complete"
