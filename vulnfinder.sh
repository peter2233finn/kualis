#! /bin/bash

folder="$1"

function notContain () {
# This will search for phrases that ARE NOT in the file
# useful for finding missing HTTP security headers

# 1 - error message
# 2 - file
# 3 - missing string

	rm /tmp/vulnFinder.tmp
	find "$folder" -name "$2" | while read file; do
		grep -riL "$3" $file >> /tmp/vulnFinder.tmp
		
	done
	
	if [ $(wc -l /tmp/vulnFinder.tmp | awk '{print $1}') -ne 0 ]; then
		printf "\n\n$1\n"
		cat /tmp/vulnFinder.tmp		
	fi

}

function simpleFind () {
# This is a simple find function that will use grep -R with an initial value then any other values will grep this after

# 1 - issue
# 2 - initial grep. Will run Grep -R $2 folder
# 3+ - actions to grep. This will be added as " | grep $this"
	
	# find number of issues to grep
	lock=0
	toRun="grep -R \"$2\" $folder"
	
	
	for i in "$@"; do
		if [ $lock -gt 1 ]; then
			toRun+=" | grep \"$i\""
		fi
		((lock++))
	done
	bash -c "$toRun" > /tmp/vulnFinder.tmp

	if [ -s /tmp/vulnFinder.tmp ]; then
		printf "\n\n$1\n"
		cat /tmp/vulnFinder.tmp
	fi
}

function regexFind () {
# This function will search via grep regex using -E option. It works the same way as the simpleFind function. 

# 1 - issue
# 2 - regex grep. Will run Grep -R -E $2 folder
# 3+ - additional actions to grep. This will be added as " | grep $this"
	
	# find number of issues to grep
	lock=0
	toRun="grep -R -E \"$2\" $folder"
	for i in "$@"; do
		if [ $lock -gt 1 ]; then
			toRun+=" | grep -Ei \"$i\""
		fi
		((lock++))
	done
	bash -c "$toRun" > /tmp/vulnFinder.tmp

	if [ -s /tmp/vulnFinder.tmp ]; then
		printf "\n\n$1\n"
		cat /tmp/vulnFinder.tmp
	fi
}


simpleFind "HIGH: SSLv2 is enabled" "SSLv2" "enabled" "sslscan"
simpleFind "HIGH: SSLv3 is enabled" "SSLv3" "enabled" "sslscan"
regexFind  "HIGH: Weak ciphers are in use. RC4/3DES" "3DES|RC4" "sslscan"
simpleFind "HIGH: Plaintext Protocol: FTP is enabled" "open"  "ftp" "ftp-nmap-scripts"
simpleFind "HIGH: Plaintext Protocol: Telnet is enabled" "open"  "telnet" "telnet-nmap-scripts"
simpleFind "HIGH: Plaintext Protocol: The server accepts HTTP connections with code 200. may not redirect to HTTPS supported port" "200 OK" "curl-to-root-http"
simpleFind "HIGH: IKE Handshake Discovered as 3DES:" "Handshake returned" "3DES" "ike-scan"
simpleFind "HIGH: IKE Handshake Discovered. This can be brute-forced offline" "Handshake returned" "ike-scan"
simpleFind "HIGH: NTP version 4 in use. This has known vulnrabilities (Monlist amplification, buffer overflows ect)" "NTP v4" "nmap"
simpleFind "HIGH: NTP version 3 in use. This has known vulnrabilities" "NTP v3" "nmap"


regexFind  "MEDIUM: The SSL certificate is issued by an IP address (self-signed)" '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "Issuer" "sslscan"
regexFind  "MEDIUM: The SSH server is using weak algorythms/hashes/mac" "algorithm to remove|\[fail\]" "ssh-audit"
simpleFind "MEDIUM: No SCSV Fallback in use " "Server does not support TLS Fallback SCSV" "sslscan"
simpleFind "MEDIUM: SSL/TLS - TLSv1.0 is enabled." "TLSv1.0" "enabled" "sslscan"
simpleFind "MEDIUM: SMB message signing not required." "Message signing enabled but not required" "smb-nmap-scripts"
regexFind "MEDIUM: Legacy protocols are in use on the server" "open" "echo|daytime|discard|chargen" "/nmap:"
notContain "MEDIUM: HTTP Security header: X-Frame-Options not found" "curl-to-root" "x-frame-options"
notContain "MEDIUM: HTTP Security header: X-Content-Type-Options not found" "curl-to-root" "X-Content-Type-Options"
notContain "MEDIUM: HTTP Security header: X-XSS-Protection not found" "curl-to-root" "X-XSS-Protection"
notContain "MEDIUM: HTTP Security header: Content-Security-Policy not found" "curl-to-root" "Content-Security-Policy"
notContain "MEDIUM: HTTP Security header: Strict-Transport-Security not found" "curl-to-root" "Strict-Transport-Security"

regexFind "LOW: HTTP Security Headers are not present." "header is not set|header is not present.|header is not defined." "nikto"
regexFind "LOW: Internal IP address exposed." "IP address found in the '.*' header" "nikto"
simpleFind "LOW: Risky HTTP methods" "Potentially risky methods" "nmap"
simpleFind "LOW: Trace method allowed" "Access-Control-Allow-Methods" "curl-to-root"
simpleFind "LOW: SSL/TLS - TLSv1.1 is enabled." "TLSv1.1" "enabled" "sslscan"


simpleFind "INFO: SSH Version detected" "OpenSSH " "nmap-ssh-no-brute" 
simpleFind "INFO: Mssql version identification" "Product_Version:" "mssql-nmap-scripts"
regexFind "INFO: HTTP headers reveal information" "Server:|x-aspnet-version:|X-Powered-By:" "curl-to-root"
