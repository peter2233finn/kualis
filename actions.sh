#! /bin/bash

function sortFile {
	# $1 complete file
	# $2 string to search
	touch "$(echo "$1" | tr '/' ' '| awk '{$NF=""}1' | tr ' ' '/' )/issues" 2> /dev/null
	grep -i "$2" "$1" | tee -a "$(echo "$1" | tr '/' ' '| awk '{$NF=""}1' | tr ' ' '/' )/issues" > /dev/null
}


function http-function {
	ip=$1; port=$2; folder=$3
	curl -v "http://${ip}:${port}" > "${folder}curl-to-root" 2>&1
	curl -v "http://${ip}:${port}/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 15; echo)" > "${folder}curl-to-random-directory" 2>&1
	blacklist=$(cat "${folder}curl-to-random-directory" | grep '< HTTP/' | awk '{print $3}')
	timeout 1900 gobuster dir -k -u http://${ip}:${port} -w /usr/share/dirb/wordlists/common.txt -b ${blacklist} -o "${folder}gobuster" 2> /dev/null > /dev/null
	timeout 1900 nikto -Tuning 01234abcx57896 -host http://${ip}:${port} -Plugins headers outdated httpoptions robots origin_reflection put_del_test shellshock cgi docker_registry favicon apacheusers msgs report_text content_search parked paths tests 2>&1 > "${folder}nikto"
	sortFile "${folder}nikto" "header is not"
}



function ssh-function {
	ip=$1; port=$2; folder=$3
	ssh-audit ${ip} -p ${port} > "${folder}ssh-audit"
	nmap -Pn ${ip} -p ${port} -sV --script="ssh* and not brute"  > "${folder}nmap-ssh-no-brute"
	nmap -Pn ${ip} -p ${port} -sV --script="ssh-brute"  > "${folder}nmap-ssh-brute-force"
}

function https-function {
	ip=$1; port=$2; folder=$3
	curl --insecure -v "https://${ip}:${port}" > "${folder}curl-to-root" 2>&1
	curl --insecure -v "https://${ip}:${port}/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 15; echo)" > "${folder}curl-to-random-directory" 2>&1
	blacklist=$(cat "${folder}curl-to-random-directory" | grep '< HTTP/' | awk '{print $3}')
	
	timeout 1900 gobuster dir -k -u https://${ip}:${port} -b ${blacklist} -w /usr/share/dirb/wordlists/common.txt -o "${folder}gobuster" 2> /dev/null > /dev/null
	timeout 1900 nikto -Tuning 01234abcx57896 -host https://${ip}:${port} -Plugins headers outdated httpoptions robots origin_reflection put_del_test shellshock cgi docker_registry favicon apacheusers msgs report_text content_search parked paths tests 2>&1 > "${folder}nikto"
	
}

function ssl-function {
	ip=$1; port=$2; folder=$3
	sslscan ${ip}:${port} > "${folder}sslscan"
}

function smtp-function {
	ip=$1; port=$2; folder=$3
	timeout 60 sendmail -t test@test.com -f test@test.com -s ${ip} -u "Testing SMTP Relay" 2>&1 > "${folder}SMTP-Relay-test"
	nmap ${ip} -p ${port} --script="*smtp*" -Pn  > ${folder}nmap-smtp-scripts"
	smtp-user-enum -t ${ip} -p ${port} -U /usr/share/wordlists/common-snmp-community-strings.txt  > ${folder}smtp-user-enum"
}

function snmp-function {
	ip=$1; port=$2; folder=$3
	snmpbulkwalk -c public -v2c ${ip} .  > "${folder}snmp-bulk-walk"
	timeout 20 snmpbulkwalk -c public -v1 ${ip} .  > "${folder}snmp-bulk-walk-v1"
	timeout 20 snmpbulkwalk -c public -v2c ${ip} .  > "${folder}snmp-bulk-walk-v2c"
	nmap -Pn ${ip} -p ${port} --script="snmp*"  > "${folder}snmp-nmap-scripts"
}

function mysql-function {
	ip=$1; port=$2; folder=$3
	nmap ${ip} -p ${port} -Pn --script="mysql*" > ${folder}nmap-mysql-scripts
	hydra -L /usr/share/wordlists/usernames.txt -P /usr/share/wordlists/rockyou.txt ${ip} mysql -I -s ${port} -o ${folder}mysql-hydra
}

function telnet-function {
	ip=$1; port=$2; folder=$3
	nmap ${ip} -p ${port} -Pn --script="*telnet*"  > ${folder}nmap-script-telnet

}

function unknown-function {
	ip=$1; port=$2; folder=$3
	nmap -sV -sC ${ip} -p ${port} --script="*" > ${folder}nmap-unknown 2>&1
	nmap -sV -sC ${ip} -p ${port} --version-all > ${folder}nmap-all-probes 2>&1
	curl --insecure https://${ip}:${port} > ${folder}unknown-curl-https 2>&1
	curl http://${ip}:${port} > ${folder}unknown-curl-http 2>&1
}

function msrpc-function {
	ip=$1; port=$2; folder=$3
	timeout 300 rpcdump.py ${ip} > ${folder}rpcdump-without-port
	timeout 300 rpcdump.py ${ip} -p ${port} > ${folder}rpcdump-to-port
}

function microsoft-ds-function {
	ip=$1; port=$2; folder=$3
	nmap -sV -sC ${ip} -p ${port} --script="smb*" -Pn > ${folder}SMB-scripts-nmap
	timeout 60 nbtscan -r ${ip} > ${folder}nbtscan 2>&1
}


function ftp-function {
	ip=$1; port=$2; folder=$3
	nmap -sV -sC -Pn ${ip} -p ${port} --script="*ftp*" > ${folder}ftp-nmap-scripts
}

function test-function {
	ip=$1; port=$2; folder=$3
}

function test-function {
	ip=$1; port=$2; folder=$3
}

function test-function {
	ip=$1; port=$2; folder=$3
}
