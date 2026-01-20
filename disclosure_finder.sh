#!/bin/bash

DOMAINS="domains.txt"
OUTDIR="bounty-results"
KEYWORDS="responsible|disclosure|security.txt|bug|bounty|reward|hall.of.fame|white.hat"

HTTPX=$HOME/go/bin/httpx
GAU=$HOME/go/bin/gau
mkdir -p "$OUTDIR"

echo "[+] Scanning domains for disclosure / bounty pages..."

# 1️⃣ Archive discovery
while read -r d; do
  echo "[*] $d"
  $GAU "$d" 2>/dev/null \
    | grep -Ei "$KEYWORDS" \
    | sed "s#^#[$d] #" \
    >> "$OUTDIR/raw_hits.txt"
done < "$DOMAINS"

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

while read -r line; do
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
