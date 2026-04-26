#!/usr/bin/env bash

set -uo pipefail

# ─────────────────────────────────────────────
#  COLORS & STYLES
# ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ─────────────────────────────────────────────
#  GLOBALS
# ─────────────────────────────────────────────
IP=""
OUTDIR="$(pwd)"
SCAN_TCP=false
SCAN_UDP=false
SHOW_INFO=false
CURRENT_RUN_TCP=false
CURRENT_RUN_UDP=false
START_TIME=""
TCP_PORTS_FOUND=""
UDP_PORTS_FOUND=""

# ─────────────────────────────────────────────
#  BANNER
# ─────────────────────────────────────────────
print_banner() {
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║  ███████╗███████╗██████╗  ██████╗ ███████╗ ██████╗ █████╗ ███╗  ║"
    echo "  ║     ███╔╝██╔════╝██╔══██╗██╔═══██╗██╔════╝██╔════╝██╔══██╗████╗ ║"
    echo "  ║    ███╔╝ █████╗  ██████╔╝██║   ██║███████╗██║     ███████║██╔██╗ ║"
    echo "  ║   ███╔╝  ██╔══╝  ██╔══██╗██║   ██║╚════██║██║     ██╔══██║██║╚██╗║"
    echo "  ║  ███████╗███████╗██║  ██║╚██████╔╝███████║╚██████╗██║  ██║██║ ╚██║"
    echo "  ║  ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚╝"
    echo "  ║                    S C A N N E R  v2.0                            ║"
    echo "  ╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ─────────────────────────────────────────────
#  UI HELPERS
# ─────────────────────────────────────────────
box_header() {
    local title="$1"
    local color="${2:-$CYAN}"
    local width=55
    local titlelen=${#title}
    local pad=$(( (width - titlelen - 2) / 2 ))
    local line=$(printf '═%.0s' $(seq 1 $width))
    echo -e "${color}╔${line}╗${RESET}"
    printf "${color}║%${pad}s${BOLD} %s ${RESET}${color}%${pad}s║${RESET}\n" "" "$title" ""
    echo -e "${color}╚${line}╝${RESET}"
}

section_line() {
    echo -e "${DIM}  ────────────────────────────────────────────────────────${RESET}"
}

print_status() {
    local icon="$1"
    local msg="$2"
    local color="${3:-$WHITE}"
    echo -e "  ${color}${icon}${RESET}  ${msg}"
}

spinner() {
    local pid=$1
    local msg="$2"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${RESET}  ${msg}  " "${frames[$((i % ${#frames[@]}))]}"
        sleep 0.08
        ((i++)) || true
    done
    tput cnorm 2>/dev/null || true
    printf "\r%70s\r" ""
}

elapsed_time() {
    local end_time
    end_time=$(date +%s)
    local elapsed=$(( end_time - START_TIME ))
    printf "%dm %02ds" $((elapsed / 60)) $((elapsed % 60))
}

# ─────────────────────────────────────────────
#  HELP
# ─────────────────────────────────────────────
show_help() {
    print_banner
    echo -e "${BOLD}${WHITE}  USAGE${RESET}"
    section_line
    echo -e "  ${CYAN}zeroscan${RESET} <IP> [OPTIONS]"
    echo ""
    echo -e "${BOLD}${WHITE}  OPTIONS${RESET}"
    section_line
    printf "  ${GREEN}%-22s${RESET} %s\n" "-h, --help"         "Show this help page"
    printf "  ${GREEN}%-22s${RESET} %s\n" "-t, --tcp"          "Run TCP scan only"
    printf "  ${GREEN}%-22s${RESET} %s\n" "-u, --udp"          "Run UDP scan only"
    printf "  ${GREEN}%-22s${RESET} %s\n" "-tu, -ut, --all"    "Run both TCP and UDP scans"
    printf "  ${GREEN}%-22s${RESET} %s\n" "-i, --info"         "Show port info and suggestions"
    printf "  ${GREEN}%-22s${RESET} %s\n" "-A"                 "TCP + UDP + INFO together"
    printf "  ${GREEN}%-22s${RESET} %s\n" "-o, --output DIR"   "Output directory (default: cwd)"
    printf "  ${GREEN}%-22s${RESET} %s\n" "--output=DIR"       "Output directory (equals syntax)"
    echo ""
    echo -e "${BOLD}${WHITE}  EXAMPLES${RESET}"
    section_line
    echo -e "  ${DIM}zeroscan 10.10.10.10 -t${RESET}"
    echo -e "  ${DIM}zeroscan 10.10.10.10 -tu -i${RESET}"
    echo -e "  ${DIM}zeroscan 10.10.10.10 -A${RESET}"
    echo -e "  ${DIM}zeroscan 10.10.10.10 -o /tmp/scan -t${RESET}"
    echo ""
    echo -e "${BOLD}${WHITE}  NOTES${RESET}"
    section_line
    echo -e "  ${YELLOW}▸${RESET}  IP address is required"
    echo -e "  ${YELLOW}▸${RESET}  At least one scan type must be selected"
    echo -e "  ${YELLOW}▸${RESET}  TCP uses rustscan + nmap fallback"
    echo -e "  ${YELLOW}▸${RESET}  UDP scan may be slow"
    echo ""
}

# ─────────────────────────────────────────────
#  PORT INFO
# ─────────────────────────────────────────────
port_info() {
    local proto="$1"
    local port="$2"
    local label=""
    local hint=""

    case "${proto}/${port}" in
        tcp/21)    label="FTP";             hint="check anonymous login, writable shares, and file access" ;;
        tcp/22)    label="SSH";             hint="enumerate usernames, auth methods, private keys, credential reuse" ;;
        tcp/23)    label="Telnet";          hint="plaintext auth, default credentials, banner grabbing" ;;
        tcp/25)    label="SMTP";            hint="VRFY/EXPN user enum, relay scenarios" ;;
        tcp/53)    label="DNS/TCP";         hint="zone transfer (AXFR), subdomain enum, version detection" ;;
        tcp/80|tcp/81|tcp/3000|tcp/5000|tcp/8000|tcp/8080|tcp/8081|tcp/8181|tcp/8888)
                   label="HTTP";            hint="title/headers, tech stack, robots.txt, login panel, directory brute-force" ;;
        tcp/111)   label="RPCBind";         hint="check alongside NFS and related RPC services" ;;
        tcp/135)   label="MSRPC";           hint="Windows host — check for extra RPC attack surface" ;;
        tcp/139|tcp/445)
                   label="SMB";             hint="share enum, null session, signing check, guest access" ;;
        tcp/389)   label="LDAP";            hint="naming context, anonymous bind, domain info" ;;
        tcp/443)   label="HTTPS";           hint="certificate/SANs, title, headers, vhost enumeration" ;;
        tcp/587)   label="SMTP Submission"; hint="auth mechanisms and TLS support" ;;
        tcp/631)   label="IPP/CUPS";        hint="printer management or info leakage" ;;
        tcp/873)   label="rsync";           hint="anonymous module listing and exposed share contents" ;;
        tcp/993)   label="IMAPS";           hint="mail surface, certificate clues" ;;
        tcp/995)   label="POP3S";           hint="mail-related attack surface" ;;
        tcp/1433)  label="MSSQL";           hint="weak creds, xp_cmdshell, domain integration" ;;
        tcp/1521)  label="Oracle";          hint="SID/service name enumeration" ;;
        tcp/2049)  label="NFS";             hint="showmount, exports, no_root_squash" ;;
        tcp/2375)  label="Docker API";      hint="unauthenticated access can be very critical" ;;
        tcp/3306)  label="MySQL";           hint="weak creds, database names, user enumeration" ;;
        tcp/3389)  label="RDP";             hint="NLA status, domain/local users, credential reuse" ;;
        tcp/5432)  label="PostgreSQL";      hint="roles, databases, extension enumeration" ;;
        tcp/5900)  label="VNC";             hint="auth status and weak password testing" ;;
        tcp/5985|tcp/5986)
                   label="WinRM";           hint="critical for post-cred shell access" ;;
        tcp/6379)  label="Redis";           hint="unauthenticated access can be very critical" ;;
        tcp/8009)  label="AJP";             hint="consider together with Tomcat" ;;
        tcp/8089)  label="Splunkd";         hint="Splunk management/API surface" ;;
        tcp/8443)  label="HTTPS-alt";       hint="admin panel or appliance interface" ;;
        tcp/9000)  label="App/PHP-FPM";     hint="identify service type via banner and behavior" ;;
        tcp/9090)  label="Web Console";     hint="management or monitoring panel" ;;
        tcp/9200)  label="Elasticsearch";   hint="auth status and index exposure" ;;
        tcp/9418)  label="Git";             hint="open repo or metadata exposure" ;;
        tcp/27017) label="MongoDB";         hint="unauthenticated access and database listing" ;;
        udp/53)    label="DNS";             hint="resolver behavior and records may reveal info" ;;
        udp/67|udp/68) label="DHCP";        hint="may reveal network service context" ;;
        udp/69)    label="TFTP";            hint="no auth by design — file read/write scenarios" ;;
        udp/111)   label="RPCBind";         hint="consider alongside NFS and RPC services" ;;
        udp/123)   label="NTP";             hint="time sync info, old amplification scenarios" ;;
        udp/137|udp/138) label="NetBIOS";   hint="may reveal host, user, and domain names" ;;
        udp/161)   label="SNMP";            hint="public/private community strings are highly valuable" ;;
        udp/162)   label="SNMP Trap";       hint="may indicate management infrastructure" ;;
        udp/500)   label="ISAKMP/IKE";      hint="VPN presence and fingerprinting" ;;
        udp/514)   label="Syslog";          hint="centralized logging or info leakage" ;;
        udp/520)   label="RIP";             hint="routing info disclosure" ;;
        udp/623)   label="IPMI";            hint="highly critical — auth issues and hash retrieval" ;;
        udp/1434)  label="MSSQL Browser";   hint="may leak MSSQL instance information" ;;
        udp/1900)  label="SSDP/UPnP";       hint="device and service discovery data" ;;
        udp/4500)  label="IPsec NAT-T";     hint="VPN infrastructure indicator" ;;
        udp/5353)  label="mDNS";            hint="hostname/service discovery details" ;;
        *)         label="Unknown";         hint="app-specific service — analyze banner and behavior" ;;
    esac

    printf "  ${MAGENTA}%-6s${RESET}  ${BOLD}${WHITE}%-20s${RESET}  ${DIM}%s${RESET}\n" \
        "${port}/${proto}" "${label}" "${hint}"
}

# ─────────────────────────────────────────────
#  ARG PARSING
# ─────────────────────────────────────────────
parse_args() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0 ;;
            -o|--output)
                shift
                if [[ -z "${1:-}" ]]; then
                    print_status "✖" "Error: provide a directory for -o | --output" "$RED"
                    exit 1
                fi
                OUTDIR="$1"
                shift ;;
            --output=*)
                OUTDIR="${1#*=}"
                shift ;;
            -t|--tcp)   SCAN_TCP=true;  shift ;;
            -u|--udp)   SCAN_UDP=true;  shift ;;
            -tu|-ut|--all)
                SCAN_TCP=true; SCAN_UDP=true; shift ;;
            -i|--info)  SHOW_INFO=true; shift ;;
            -A)
                SCAN_TCP=true; SCAN_UDP=true; SHOW_INFO=true; shift ;;
            -*)
                print_status "✖" "Unknown argument: $1" "$RED"
                echo
                show_help
                exit 1 ;;
            *)
                if [[ -z "$IP" ]]; then
                    IP="$1"
                elif [[ "$OUTDIR" == "$(pwd)" ]]; then
                    OUTDIR="$1"
                else
                    print_status "✖" "Extra or invalid argument: $1" "$RED"
                    exit 1
                fi
                shift ;;
        esac
    done

    if [[ -z "$IP" ]]; then
        print_status "✖" "Error: IP address is required." "$RED"
        echo
        show_help
        exit 1
    fi

    if [[ "$SCAN_TCP" == false && "$SCAN_UDP" == false ]]; then
        print_status "✖" "Error: Select at least one scan type. (-t | -u | -tu | -A)" "$RED"
        echo
        show_help
        exit 1
    fi
}

# ─────────────────────────────────────────────
#  DEPENDENCY CHECK
# ─────────────────────────────────────────────
check_dependencies() {
    if ! command -v nmap >/dev/null 2>&1; then
        print_status "✖" "nmap is not installed." "$RED"
        exit 1
    fi
    if [[ "$SCAN_TCP" == true ]]; then
        if ! command -v rustscan >/dev/null 2>&1; then
            print_status "✖" "rustscan is not installed (required for TCP scanning)." "$RED"
            exit 1
        fi
    fi
}

# ─────────────────────────────────────────────
#  OUTPUT DIR
# ─────────────────────────────────────────────
prepare_output_dir() {
    if [[ ! -d "$OUTDIR" ]]; then
        print_status "◉" "Directory not found — creating: ${OUTDIR}" "$YELLOW"
        mkdir -p "$OUTDIR" || {
            print_status "✖" "Could not create directory: ${OUTDIR}" "$RED"
            exit 1
        }
    fi
}

cleanup_run_files() {
    rm -f \
        "$OUTDIR/tcp_ports.txt" \
        "$OUTDIR/tcp_ports_rustscan.txt" \
        "$OUTDIR/tcp_ports_nmap.txt" \
        "$OUTDIR/udp_ports.txt"
}

# ─────────────────────────────────────────────
#  TCP SCAN
# ─────────────────────────────────────────────
scan_tcp() {
    local rust_file="$OUTDIR/tcp_ports_rustscan.txt"
    local nmap_file="$OUTDIR/tcp_ports_nmap.txt"
    local final_file="$OUTDIR/tcp_ports.txt"

    CURRENT_RUN_TCP=true
    box_header "TCP SCAN" "$CYAN"

    # rustscan
    print_status "⟳" "Running rustscan (ulimit 5000)..." "$CYAN"
    {
        rustscan -a "$IP" --ulimit 5000 -g 2>/dev/null \
            | awk -F'[][]' 'NF>1 {print $2}' \
            | tr ',' '\n' \
            | sed '/^[[:space:]]*$/d' \
            | sed 's/[[:space:]]//g' \
            | awk '/^[0-9]+$/' \
            | sort -n -u \
            > "$rust_file"
    } &
    spinner $! "Rustscan running..."

    local rust_count
    rust_count=$(wc -l < "$rust_file" 2>/dev/null || echo 0)
    print_status "✔" "Rustscan found ${rust_count} port(s)" "$GREEN"

    # nmap fallback
    print_status "⟳" "Running nmap top-1000 fallback..." "$CYAN"
    {
        nmap -Pn -n --top-ports 1000 --open -oG - "$IP" 2>/dev/null \
            | awk -F'Ports: ' '/Ports: / {print $2}' \
            | tr ',' '\n' \
            | awk -F'/' '$2=="open" {print $1}' \
            | sed '/^[[:space:]]*$/d' \
            | sed 's/[[:space:]]//g' \
            | awk '/^[0-9]+$/' \
            | sort -n -u \
            > "$nmap_file"
    } &
    spinner $! "Nmap fallback running..."

    cat "$rust_file" "$nmap_file" 2>/dev/null \
        | sed '/^[[:space:]]*$/d' \
        | awk '/^[0-9]+$/' \
        | sort -n -u \
        > "$final_file"

    TCP_PORTS_FOUND="$(paste -sd, "$final_file" 2>/dev/null || true)"

    if [[ -z "$TCP_PORTS_FOUND" ]]; then
        print_status "⚠" "No open TCP ports found." "$YELLOW"
        return
    fi

    echo ""
    echo -e "  ${GREEN}${BOLD}Open TCP Ports:${RESET}  ${WHITE}${TCP_PORTS_FOUND}${RESET}"
    section_line
    echo ""

    # Version scan
    print_status "⟳" "Version scan (sV)..." "$CYAN"
    echo ""
    nmap -Pn -n -sV -p "$TCP_PORTS_FOUND" "$IP" -oN "$OUTDIR/VersionScan_TCP.txt"
    echo ""
    print_status "✔" "Saved → ${OUTDIR}/VersionScan_TCP.txt" "$GREEN"
    echo ""

    # Script scan
    print_status "⟳" "Script scan (sC)..." "$CYAN"
    echo ""
    nmap -Pn -n -sC -p "$TCP_PORTS_FOUND" "$IP" -oN "$OUTDIR/ScriptScan_TCP.txt"
    echo ""
    print_status "✔" "Saved → ${OUTDIR}/ScriptScan_TCP.txt" "$GREEN"
}

# ─────────────────────────────────────────────
#  UDP SCAN
# ─────────────────────────────────────────────
scan_udp() {
    local udp_file="$OUTDIR/udp_ports.txt"

    CURRENT_RUN_UDP=true
    box_header "UDP SCAN" "$YELLOW"
    print_status "⚠" "UDP scan may be slow — please wait..." "$YELLOW"
    echo ""

    {
        nmap -Pn -n -sU --top-ports 200 -oG - "$IP" 2>/dev/null \
            | awk -F'Ports: ' '/Ports: / {print $2}' \
            | tr ',' '\n' \
            | awk -F'/' '$2=="open" || $2=="open|filtered" {print $1}' \
            | sed '/^[[:space:]]*$/d' \
            | sed 's/[[:space:]]//g' \
            | awk '/^[0-9]+$/' \
            | sort -n -u \
            > "$udp_file"
    } &
    spinner $! "UDP scanning top 200 ports..."

    UDP_PORTS_FOUND="$(paste -sd, "$udp_file" 2>/dev/null || true)"

    if [[ -z "$UDP_PORTS_FOUND" ]]; then
        print_status "⚠" "No open UDP ports found." "$YELLOW"
        return
    fi

    echo ""
    echo -e "  ${GREEN}${BOLD}Open UDP Ports:${RESET}  ${WHITE}${UDP_PORTS_FOUND}${RESET}"
    section_line
    echo ""

    print_status "⟳" "UDP version scan (sU sV)..." "$CYAN"
    echo ""
    nmap -Pn -n -sU -sV -p "$UDP_PORTS_FOUND" "$IP" -oN "$OUTDIR/VersionScan_UDP.txt"
    echo ""
    print_status "✔" "Saved → ${OUTDIR}/VersionScan_UDP.txt" "$GREEN"
}

# ─────────────────────────────────────────────
#  PORT INFO PANEL
# ─────────────────────────────────────────────
generate_info() {
    box_header "PORT INTELLIGENCE" "$MAGENTA"
    printf "  ${DIM}%-6s  %-20s  %s${RESET}\n" "PORT" "SERVICE" "NOTES"
    section_line

    if [[ "$CURRENT_RUN_TCP" == true && -f "$OUTDIR/tcp_ports.txt" ]]; then
        while IFS= read -r port; do
            [[ -n "$port" ]] && port_info "tcp" "$port"
        done < "$OUTDIR/tcp_ports.txt"
    fi

    if [[ "$CURRENT_RUN_UDP" == true && -f "$OUTDIR/udp_ports.txt" ]]; then
        while IFS= read -r port; do
            [[ -n "$port" ]] && port_info "udp" "$port"
        done < "$OUTDIR/udp_ports.txt"
    fi

    section_line
}

# ─────────────────────────────────────────────
#  SUMMARY DASHBOARD
# ─────────────────────────────────────────────
print_summary() {
    local elapsed
    elapsed=$(elapsed_time)

    echo ""
    box_header "SCAN SUMMARY" "$GREEN"

    printf "  ${DIM}%-20s${RESET}  %s\n"    "Target"       "${WHITE}${IP}${RESET}"
    printf "  ${DIM}%-20s${RESET}  %s\n"    "Output dir"   "${WHITE}${OUTDIR}${RESET}"
    printf "  ${DIM}%-20s${RESET}  %s\n"    "Elapsed time" "${WHITE}${elapsed}${RESET}"
    section_line

    if [[ "$CURRENT_RUN_TCP" == true ]]; then
        if [[ -n "$TCP_PORTS_FOUND" ]]; then
            printf "  ${GREEN}%-20s${RESET}  %s\n" "TCP ports" "${TCP_PORTS_FOUND}"
        else
            printf "  ${YELLOW}%-20s${RESET}  %s\n" "TCP ports" "none found"
        fi
    fi

    if [[ "$CURRENT_RUN_UDP" == true ]]; then
        if [[ -n "$UDP_PORTS_FOUND" ]]; then
            printf "  ${GREEN}%-20s${RESET}  %s\n" "UDP ports" "${UDP_PORTS_FOUND}"
        else
            printf "  ${YELLOW}%-20s${RESET}  %s\n" "UDP ports" "none found"
        fi
    fi

    section_line
    echo -e "  ${CYAN}Output files:${RESET}"
    for f in "$OUTDIR"/*.txt; do
        [[ -f "$f" ]] && printf "  ${DIM}  ▸  %s${RESET}\n" "$(basename "$f")"
    done
    echo ""
    echo -e "  ${GREEN}${BOLD}✔  Scan completed.${RESET}"
    echo ""
}

# ─────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────
main() {
    parse_args "$@"
    START_TIME=$(date +%s)

    print_banner

    CURRENT_RUN_TCP=false
    CURRENT_RUN_UDP=false
    check_dependencies
    prepare_output_dir
    cleanup_run_files

    echo ""
    section_line
    print_status "◉" "Target:      ${WHITE}${IP}${RESET}" "$CYAN"
    print_status "◉" "Output dir:  ${WHITE}${OUTDIR}${RESET}" "$CYAN"
    section_line
    echo ""

    if [[ "$SCAN_TCP" == true ]]; then
        scan_tcp
        echo ""
    fi

    if [[ "$SCAN_UDP" == true ]]; then
        scan_udp
        echo ""
    fi

    if [[ "$SHOW_INFO" == true ]]; then
        generate_info
        echo ""
    fi

    print_summary
}

main "$@"
