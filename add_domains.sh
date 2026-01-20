#!/bin/bash

OUTPUT="domains.txt"
TMP="/tmp/all_domains.txt"
COUNT=200

echo "[+] Fetching domains from public sources..."

> "$TMP"

# -----------------------------
# HackerOne
# -----------------------------
curl -s https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/master/data/hackerone_data.json \
 | jq -r '..|.asset_identifier? // empty' \
 >> "$TMP"

# -----------------------------
# Bugcrowd
# -----------------------------
curl -s https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/master/data/bugcrowd_data.json \
 | jq -r '..|.target? // empty' \
 >> "$TMP"

# -----------------------------
# Intigriti
# -----------------------------
curl -s https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/master/data/intigriti_data.json \
 | jq -r '..|.endpoint? // empty' \
 >> "$TMP"

# -----------------------------
# Fortune 500
# -----------------------------
curl -s https://raw.githubusercontent.com/ozlerhakan/mongodb-json-files/master/datasets/fortune500.json \
 | jq -r '.[].website' \
 >> "$TMP"

# -----------------------------
# US Gov domains
# -----------------------------
curl -s https://raw.githubusercontent.com/GSA/data/master/dotgov-domains/current-full.csv \
 | cut -d',' -f1 \
 | tail -n +2 \
 >> "$TMP"

echo "[+] Normalizing and deduplicating domains..."

# Normalize + clean
sed 's#https\?://##;s#/.*##;s/\*\.//' "$TMP" \
 | grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' \
 | sort -u > "$TMP.clean"

# Remove existing domains
if [[ -f "$OUTPUT" ]]; then
  grep -vxF -f "$OUTPUT" "$TMP.clean" > "$TMP.new"
else
  cp "$TMP.clean" "$TMP.new"
fi

echo "[+] Selecting $COUNT random domains..."

# Add 200 domains
shuf "$TMP.new" | head -n "$COUNT" >> "$OUTPUT"

echo "[✓] Added up to $COUNT domains to $OUTPUT"

# Cleanup
rm -f "$TMP" "$TMP.clean" "$TMP.new"
