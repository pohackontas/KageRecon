# 𓆰𓆪 KageRecon  — Automated Reconnaissance & Continuous Monitoring Framework


_A modular, Docker-ready recon pipeline for Red Team, Bug Bounty and External Pentesting._


##  Overview

  
**𓆰𓆪 KageRecon** is a fully automated reconnaissance and continuous-monitoring framework designed for long-running external assessments, red teaming and attack-surface discovery.

It combines:
- subdomain enumeration
- IP/CIDR filtering
- mass scanning
- service fingerprinting
- web discovery & crawling
- nuclei scanning (diff-based)
- screenshotting with deduplication
- structured target grouping
- optional integrations (Acunetix, BruteSpray)
- Docker-based isolated execution
- support for persistent monitoring


The framework is intended for **real environments**, including VDS/VPS deployments and offline, air-gapped virtual machines.

---

##  Quick Start

  
Below are deployment scenarios extracted from real-world usage.

### **1) Fast setup on VPS (Ubuntu)**

```
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |   sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

dd if=/dev/zero of=/swapfile bs=1M count=3064
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

docker pull leonjza/gowitness

cd project
docker build --tag KageRecon:v1 .
```

---

### **2) Running on isolated/offline VM**

  

Save images:

```
docker save -o gowitness.tar leonjza/gowitness
docker save -o KageRecon.tar KageRecon:v1
```

Load them offline:

```
docker load -i gowitness.tar
docker load -i KageRecon.tar
```

---

### **3) Persistent long-term monitoring mode**

```
mkdir /mnt/reports
mkdir targets/
cd targets/
nano IP_list.txt subdomains_blacklist.txt subdomains_additional.txt

docker run -d --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /mnt/reports/:/data/ \
  -v $(pwd):/tools/KageRecon/input \
  KageRecon:v1 test.com input/IP_list.txt input/subdomains_blacklist.txt input/subdomains_additional.txt
```

---

### **4) One-time execution**

```
mkdir /mnt/reports
mkdir targets/
cd targets/
nano IP_list.txt subdomains_blacklist.txt subdomains_additional.txt

docker run --rm -d \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /mnt/reports/:/data/ \
  -v $(pwd):/tools/KageRecon/input \
  KageRecon:v1 target.domain input/IP_list.txt input/subdomains_blacklist.txt input/subdomains_additional.txt
```

---

###  **5) Debug mode (modify code without rebuilding)**

```
docker run -it --tty --entrypoint /bin/bash \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /mnt/reports/:/data/ \
  -v `pwd`:/tools/KageRecon/input \
  KageRecon:v1

./KageRecon.sh example.local input/IP_list.txt input/subdomains_blacklist.txt input/subdomains_additional.txt > $(date +"log-%Y-%m-%d_%H:%M")
```

---

## **6) Utility commands**

```
nohup docker logs 66 -n 10000 -f &> log.txt &
# Save container logs

nohup ./KageRecon.sh test.com IP_list.txt subdomains_blacklist.txt subdomains_additional.txt \
  > logs/$(date +"log-%Y-%m-%d_%H:%M") &
# Legacy launch method
```

---

# ** Parameters**

|**Param**|**Description**|
|---|---|
|$1|Main target: domain or arbitrary name (no spaces/special chars recommended). If domain — subdomain enumeration is enabled.|
|$2|Allowed IP/CIDR ranges. For single IP use /32 (temporary limitation).|
|$3|Subdomain blacklist (wildcards supported).|
|$4|Additional subdomains (IP can also be placed here, but not recommended).|

Only $1 is required.

If you encounter a case where it doesn’t work - contact the author.

---

# ** Folder Structure**

  

Base directory:
```
/mnt/reports/
```

Inside each target:

|**Path**|**Purpose**|
|---|---|
|/mnt/reports/${target}|Target directory created from subdomains/IPs|
|info/|Main work directory with all results|
|info/screenshots_trusted|Approved screenshots (first run populates this)|
|info/screenshots_new|Screenshots from subsequent scans|
|info/screenshots_diff|Differences between trusted/new screenshots|
|info/gowitness|Temporary gowitness working dir|
|info/groups|Service-based grouping|
|_container_/outOfRangeFQDN_IP.txt|FQDNs whose IPs do not match allowed IP ranges|
|_container_/all_allowed_IP.tmp|CIDR-expanded IP list|

---

# ** Files**

|**File**|**Description**|
|---|---|
|info/nuclei.txt|Baseline nuclei report|
|info/nuclei_new.txt|Reports from subsequent scans|
|info/nuclei_diff.txt|Diff between baseline and new nuclei results|
|info/nuclei_joblog.txt|Parallel job logs|
|info/subdomains.txt|Baseline subdomains|
|info/newSubdomains.txt|New subdomains from later scans|
|info/diffSubdomains.txt|Difference between old and new subdomains|
|info/new_services.txt|Newly discovered services|
|subdmsAndIP.txt|Consolidated targets|

---

# ** Internal Workflow (High-Level)**

1. Enumerate subdomains (subfinder + additional list)
2. Normalize and filter blacklist
3. Resolve IPs and check against allowed CIDR ranges
4. Perform masscan and nmap fingerprinting
5. Run httpx for live hosts
6. Launch nuclei baseline / diff scanning
7. Crawl hosts via gospider
8. Run directory brute-force via dirsearch
9. Generate screenshots via gowitness
10. Deduplicate screenshots
11. Track differences in services, subdomains, screenshots
12. Send updates via express_* (or any replacement messenger)



---

#  Disclaimer

This tool is intended **only for authorized security testing**.
The author is not responsible for misuse or unauthorized testing activities.





