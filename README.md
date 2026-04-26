# 🔍 Zeroscan

> A fast, intelligent network scanner with a beautiful CLI dashboard — built for penetration testers and CTF players.

 
<img width="1193" height="791" alt="image" src="https://github.com/user-attachments/assets/18d978d2-a435-4cfd-9c46-6f35d37ce6e4" />



---

## 💡 Why Zeroscan?

Most pentesters run the same sequence of commands on every target — rustscan, nmap version scan, nmap script scan, UDP scan — copy-pasting ports between each step. **Zeroscan automates that entire workflow in a single command.**

Here's what makes it stand out:

### ⚡ Speed — rustscan + nmap, together
Zeroscan runs **rustscan** first for blazing-fast port discovery, then immediately falls back to **nmap top-1000** to catch anything rustscan may have missed. The results are merged and deduplicated automatically. You get the speed of rustscan *and* the reliability of nmap — without running them separately.

### 🧠 No more copy-pasting ports
After discovering open ports, Zeroscan passes them directly into version (`-sV`) and script (`-sC`) scans — no manual copy-paste needed. On a typical box, this saves several minutes and prevents human error.

### 🗂️ Organized output, automatically
Every scan result is saved to a named file in your output directory:
- `VersionScan_TCP.txt`
- `ScriptScan_TCP.txt`
- `VersionScan_UDP.txt`

No more digging through terminal history to find a result from 20 minutes ago.

### 🧩 Built-in Port Intelligence (`-i` / `-A`)
After scanning, Zeroscan can print a **port intelligence panel** — a table that maps each open port to its service and gives you targeted hints for that specific protocol:

```
PORT    SERVICE              NOTES
445     SMB                  enumerate shares, null sessions, signing check, guest access
3306    MySQL                weak creds, database names, user enumeration
5985    WinRM                critical for post-cred shell access
```

No more Googling "what to do with port X" mid-engagement.

### 🎨 Clean CLI Dashboard
Color-coded sections, spinner animations while scans run, and a final summary dashboard showing elapsed time, all discovered ports, and saved output files — so you always know exactly where you are in the process.

### 🚀 One flag to rule them all: `-A`
```bash
./zeroscan.sh 10.10.10.10 -A
```
This single command runs TCP discovery → version scan → script scan → UDP scan → port intelligence panel. Everything. Done.

---

## 📦 Requirements

| Tool | Purpose |
|------|---------|
| `nmap` | Port scanning, version & script detection |
| `rustscan` | Fast TCP port discovery |
| `bash` | v4.0+ |

Install on Kali / Debian:
```bash
sudo apt install nmap
# rustscan: https://github.com/RustScan/RustScan/releases
```

---

## 🚀 Installation

```bash
git clone https://github.com/umid1988/zeroscan.git
cd zeroscan
chmod +x zeroscan.sh
```

Optionally add to PATH:
```bash
sudo cp zeroscan.sh /usr/local/bin/zeroscan
```

---

## 🛠️ Usage

```bash
zeroscan <IP> [OPTIONS]
```

| Flag | Description |
|------|-------------|
| `-t`, `--tcp` | TCP scan only |
| `-u`, `--udp` | UDP scan only |
| `-tu`, `--all` | TCP + UDP |
| `-i`, `--info` | Show port intelligence panel |
| `-A` | TCP + UDP + INFO (recommended) |
| `-o DIR`, `--output DIR` | Output directory (default: current dir) |
| `-h`, `--help` | Show help |

---

## 📌 Examples

```bash
# Quick TCP scan
zeroscan 10.10.10.10 -t

# Full scan with port intelligence
zeroscan 10.10.10.10 -A

# Save results to a specific folder
zeroscan 10.10.10.10 -A -o /tmp/htb/target

# TCP + info only (skip UDP)
zeroscan 10.10.10.10 -t -i
```

---

## 📁 Output Files

| File | Contents |
|------|----------|
| `tcp_ports.txt` | Raw list of open TCP ports |
| `udp_ports.txt` | Raw list of open UDP ports |
| `VersionScan_TCP.txt` | nmap `-sV` results for TCP |
| `ScriptScan_TCP.txt` | nmap `-sC` results for TCP |
| `VersionScan_UDP.txt` | nmap `-sU -sV` results for UDP |

---

## ⚠️ Disclaimer

Zeroscan is intended for **authorized security testing only** — CTF platforms (HackTheBox, TryHackMe), lab environments, and systems you own or have explicit written permission to test. Unauthorized use against systems you do not own is illegal.

---

## 📄 License

MIT License — use freely, modify, contribute.
