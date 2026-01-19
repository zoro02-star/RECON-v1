#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 domain.com"
    exit 1
fi

# Variables
TARGET=$1
WORDLIST="/usr/share/wordlists/dirb/common.txt"
THREADS=10
HTTPX=$HOME/go/bin/httpx
KATANA=$HOME/go/bin/katana
AMASS=$HOME/go/bin/amass
SUBFINDER=$HOME/go/bin/subfinder
ASSETFINDER=$HOME/go/bin/assetfinder

echo "[*] Starting reconnaissance for $TARGET"
mkdir -p recon && cd recon || exit

# Subdomain Enumeration
echo "[*] Enumerating subdomains..."
$SUBFINDER -d "$TARGET" -silent > subfinder.txt
$ASSETFINDER --subs-only "$TARGET" > assetfinder.txt
$AMASS enum -passive -d "$TARGET" -timeout 2 -o amass.txt

# Sorting and Removing all the dublicates
echo "[*] Sorting and Removing all dublicated" 
cat subfinder.txt assetfinder.txt amass.txt \
| tr '[:upper:]' '[:lower:]' \
| sed 's/^https\?:\/\///' \
| sort -u > all_subs.txt

# Probe Live Hosts (CLEAN output)
echo "[*] Probing live hosts..."
$HTTPX -l all_subs.txt \
  -status-code \
  -title \
  -tech-detect \
  -content-length \
  -o live.txt

# Katana  url crawleling 
echo "[*] Crawling with Katana"
$KATANA -list live.txt \
  -depth 2 \
  -js-crawl \
  -known-files all \
  -automatic-form-fill \
  -silent \
  -o katana.txt


# Nuclei Scan
#echo "[*] Running Nuclei scans..."
#nuclei -l katana.txt -severity medium,high,critical \
#	-o nuclei_results.txt

# Directory Fuzzing (LIMITED THREADS)
echo "[*] Running directory fuzzing..."

sed 's/ \[.*$//' live.txt > clean_live.txt
mkdir -p ffuf

while read -r url; do
  host=$(echo "$url" | sed 's#https\?://##')
  echo "[*] Fuzzing $url"

  ffuf -u "$url/FUZZ" \
    -w /usr/share/wordlists/dirb/common.txt \
    -mc 200,301,302,403 \
    -t 10 \
    -of json \
    -o "ffuf/${host}.json"

done < clean_live.txt


echo "[[[*]]] Reconnaissance complete!"
