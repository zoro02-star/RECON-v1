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
mkdir -p recon-$TARGET && cd recon-$TARGET || exit

# Subdomain Enumeration
echo "[*] Enumerating subdomains..."
$SUBFINDER -d "$TARGET" -silent > subfinder.txt
$ASSETFINDER --subs-only "$TARGET" > assetfinder.txt
#$AMASS enum -passive -d "$TARGET" -timeout 10 -silent -o amass.txt

echo "[*] Sorting, de-duplicating "
cat subfinder.txt assetfinder.txt\
| tr '[:upper:]' '[:lower:]' \
| sed 's/^https\?:\/\///' \
| grep -Ev 'blog\.|university\.|humansofdata\.|docs' \
| sort -u > all_subs.txt

# Probe Live Hosts (CLEAN output)
echo "[*] Probing live hosts..."
$HTTPX -l all_subs.txt -silent -o live.txt 

# Katana  url crawling 
echo "[*] Crawling with Katana"
$KATANA -list live.txt \
  -depth 2 \
  -js-crawl \
  -known-files all \
  -silent \
  -o katana.txt


    # Nuclei Scan
    #best real-world
# echo "[*] Running Nuclei scans..."
# nuclei -l katana.txt \
#   -severity medium,high,critical \
#   -exclude-tags dos,fuzz \
#   -c 50 -rl 150 \
#   -silent \
#   -o nuclei.txt

    #increse speed safely
# nuclei -l katana.txt \
#   -c 50 \
#   -rl 150 \
#   -timeout 10 \
#   -severity medium,high,critical \
#   -silent
 
    # scans only useful bug classes:
# nuclei -l katana.txt \
#   -tags xss,sqli,lfi,ssrf,open-redirect \
#   -severity medium,high,critical

    #program-safe
# nuclei -l katana.txt \
#   -exclude-tags dos,fuzz,bruteforce \
#   -severity medium,high,critical

    #CVE-only hunting (fast money)
# nuclei -l katana.txt \
#   -tags cve \
#   -severity high,critical
  
    #API & GRAPHQL hunting
#nuclei -l katana.txt -tags api,graphql
    
    #Extract secrets instead of just vulns
#nuclei -tags token,apikey,exposure
#AWS key,firebase configs, JWTS, Internal URLs



# Directory Fuzzing (LIMITED THREADS)
echo "[*] Running directory fuzzing..."

mkdir -p ffuf
while read -r url; do
  [ -z "$url" ] && continue
  # normalize hostname for filename
  host=$(echo "$url" | sed 's#https\?://##; s#/##g')
  echo "[*] Fuzzing $url"
  ffuf -u "$url/FUZZ" \
    -w /usr/share/wordlists/dirb/common.txt \
    -mc 200,204,301,302,307,401,403 \
    -t 10 \
    -rate 50 \
    -timeout 10 \
    -of json \
    -o "ffuf/${host}.json"
done < live.txt


echo "[*] Extracting endpoints from js"
cat katana.txt \
| sed 's#https\?://[^/]*##' \
| awk -F'/' '{print "/"$2}' \
| sort -u > discovered_dirs.txt

# echo "[*] Feroxbuster (recursive deep scan)"
# feroxbuster -u https://$TARGET \
#   -w /usr/share/wordlists/dirb/common.txt \
#   -d 2 \
#   -q


echo "[[[*]]] Reconnaissance complete!"
