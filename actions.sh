#! /bin/bash
brute=true

function issueList {
	# $1 complete file
	# $2 string to search
	# $3 text to add
	tmpFile="/tmp/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 23; echo).pScan.issue.Find"
	touch "$(echo "$1" | tr '/' ' '| awk '{$NF=""}1' | tr ' ' '/' )/issues" 2> /dev/null
	
	string=$(grep -E -i "$2" "$1")
       	echo $string > $tmpFile
	
	if [ -z "$string" ]; then 
		echo "$3 $(cat $tmpFile)" | tee -a "$(echo "$1" | tr '/' ' '| awk '{$NF=""}1' | tr ' ' '/' )/issues" > /dev/null
	fi
	rm $tmpFile
}

function issueRed {
	# $1 complete file
	# $2 text to add
	tmpFile="/tmp/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 23; echo).pScan.issue.Find"
	touch "$(echo "$1" | tr '/' ' '| awk '{$NF=""}1' | tr ' ' '/' )/issues" 2> /dev/null
	string=$(cat "$1" | sed -n '/\x1b\[31m/p')
       	echo $string > $tmpFile
	if [ -z "$string" ]; then 
		echo "$2 $(cat $tmpFile)"| tee -a "$(echo "$1" | tr '/' ' '| awk '{$NF=""}1' | tr ' ' '/' )/issues" > /dev/null
	fi
	rm $tmpFile
}

function http-function {
	ip=$1; port=$2; folder=$3
	curl -v "http://${ip}:${port}" > "${folder}curl-to-root" 2>&1
	curl -v "http://${ip}:${port}/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 15; echo)" > "${folder}curl-to-random-directory" 2>&1
	blacklist=$(cat "${folder}curl-to-random-directory" | grep '< HTTP/' | awk '{print $3}')
	timeout 1900 gobuster dir -k -u http://${ip}:${port} -w /usr/share/dirb/wordlists/common.txt -b ${blacklist} -o "${folder}gobuster" 2> /dev/null > /dev/null
	timeout 1900 nikto -Tuning 01234abcx57896 -host http://${ip}:${port} -Plugins headers outdated httpoptions robots origin_reflection put_del_test shellshock cgi docker_registry favicon apacheusers msgs report_text content_search parked paths tests 2>&1 > "${folder}nikto"
	issueList "${folder}nikto" "header is not" "Missing HTTP Header: "
}


function telnet-function {
	ip=$1; port=$2; folder=$3
	nmap ${ip} -p ${port} --script "telnet* and not brute" > "${folder}/nmap-telnet-no-brute"
	[ $brute = true ] && nmap -Pn ${ip} -p ${port} -sV --script="telnet-brute"  > "${folder}nmap-telnet-brute-force"
}


function ssh-function {
	ip=$1; port=$2; folder=$3
	ssh-audit ${ip} -p ${port} > "${folder}ssh-audit"
	nmap -Pn ${ip} -p ${port} -sV --script="ssh* and not brute"  > "${folder}nmap-ssh-no-brute"
	[ $brute = true ] && nmap -Pn ${ip} -p ${port} -sV --script="ssh-brute"  > "${folder}nmap-ssh-brute-force"
}

function https-function {
	ip=$1; port=$2; folder=$3
	curl --insecure -v "https://${ip}:${port}" > "${folder}curl-to-root" 2>&1
	curl --insecure -v "https://${ip}:${port}/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 15; echo)" > "${folder}curl-to-random-directory" 2>&1
	blacklist=$(cat "${folder}curl-to-random-directory" | grep '< HTTP/' | awk '{print $3}')
	
	timeout 1900 gobuster dir -k -u https://${ip}:${port} -b ${blacklist} -w /usr/share/dirb/wordlists/common.txt -o "${folder}gobuster" 2> /dev/null > /dev/null
	timeout 1900 nikto -Tuning 01234abcx57896 -host https://${ip}:${port} -Plugins headers outdated httpoptions robots origin_reflection put_del_test shellshock cgi docker_registry favicon apacheusers msgs report_text content_search parked paths tests 2>&1 > "${folder}nikto"
	issueList "${folder}nikto" "header is not" "Missing HTTP Header: "
	
}

function ssl-function {
	ip=$1; port=$2; folder=$3
	sslscan ${ip}:${port} > "${folder}sslscan"
	issueRed "${folder}sslscan" "SSL Issue: "
}

function smtp-function {
	ip=$1; port=$2; folder=$3
	timeout 60 sendmail -t test@test.com -f test@test.com -s ${ip} -u "Testing SMTP Relay" 2>&1 > "${folder}SMTP-Relay-test"
	nmap ${ip} -p ${port} --script="*smtp* and not brute" -Pn  > "${folder}nmap-smtp-scripts"
	[ $brute = true ] && nmap ${ip} -p ${port} --script="smtp-brute" -Pn  > ${folder}nmap-smtp-brute-scripts"
	smtp-user-enum -t ${ip} -p ${port} -U /usr/share/wordlists/common-snmp-community-strings.txt  > ${folder}smtp-user-enum"
}

function snmp-function {
	ip=$1; port=$2; folder=$3
	snmpbulkwalk -c public -v2c ${ip} .  > "${folder}snmp-bulk-walk"
	timeout 20 snmpbulkwalk -c public -v1 ${ip} .  > "${folder}snmp-bulk-walk-v1"
	timeout 20 snmpbulkwalk -c public -v2c ${ip} .  > "${folder}snmp-bulk-walk-v2c"
	nmap -Pn ${ip} -p ${port} --script="snmp* and not brute"  > "${folder}snmp-nmap-scripts"
	[ $brute = true ] && nmap -Pn ${ip} -p ${port} --script="snmp-brute"  > "${folder}snmp-nmap-brute"
}

function mysql-function {
	ip=$1; port=$2; folder=$3
	nmap ${ip} -p ${port} -Pn --script="mysql* and not brute" > ${folder}nmap-mysql-scripts
	[ $brute = true ] && nmap ${ip} -p ${port} -Pn --script="mysql-brute" > ${folder}nmap-mysql-brute
	[ $brute = true ] && hydra -L /usr/share/wordlists/usernames.txt -P /usr/share/wordlists/rockyou.txt ${ip} mysql -I -s ${port} -o ${folder}mysql-hydra
}

function telnet-function {
	ip=$1; port=$2; folder=$3
	nmap ${ip} -p ${port} -Pn --script="*telnet* and not brute"  > ${folder}nmap-script-telnet
	[ $brute = true ] && nmap ${ip} -p ${port} -Pn --script="telnet-brute"  > ${folder}nmap-telnet-brute

}

function unknown-function {
	ip=$1; port=$2; folder=$3
	nmap -sV -sC ${ip} -p ${port} --script="*" > ${folder}nmap-unknown 2>&1
	nmap -sV -sC ${ip} -p ${port} --version-all > ${folder}nmap-all-probes 2>&1
	curl --insecure https://${ip}:${port} > ${folder}unknown-curl-https 2>&1
	curl http://${ip}:${port} > ${folder}unknown-curl-http 2>&1
}

function msrcp-function { 
	ip=$1; port=$2; folder=$3
	timeout 300 rpcdump.py ${ip} > ${folder}rpcdump-without-port
	timeout 300 rpcdump.py ${ip} -p ${port} > ${folder}rpcdump-to-port
}

function microsoft-ds-function {
	ip=$1; port=$2; folder=$3
	nmap -sV -sC ${ip} -p ${port} --script="smb*" -Pn > ${folder}SMB-scripts-nmap
	timeout 60 nbtscan -v -r ${ip} > ${folder}nbtscan 2>&1
	[ $brute = true ] && hydra -t 1  -f -l administrator -P /usr/share/wordlists/rockyou.txt $ip smb
	issueList "${folder}nbtscan" '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "Possibly add to scope (from nbtscan): "
	issueList "${folder}SMB-scripts-nmap" "dangerous, but default" "SMBv1 is enabled: "
}


function ftp-function {
	ip=$1; port=$2; folder=$3
	nmap -sV -sC -Pn ${ip} -p ${port} --script="*ftp* and not brute" > ${folder}ftp-nmap-scripts
	[ $brute = true ] && nmap -sV -sC -Pn ${ip} -p ${port} --script="ftp-brute" > ${folder}ftp-nmap-scripts
}

function dns-function {
	ip=$1; port=$2; folder=$3
	nmap $ip -p $port -Pn --script="dns* and not brute" > ${folder}nmap-dns
 	[ $brute = true ] && nmap $ip -p $port -Pn --script="dns-brute" > ${folder}nmap-dns-brute

}

function rpc-function {
	ip=$1; port=$2; folder=$3
	nmap $ip -p $port -Pn --script="*rpc* and not brute" > ${folder}rpc-nmap-scripts
	[ $brute = true ] && nmap ${ip} -p ${port} -Pn --script="rpcap-brute"  > ${folder}nmap-rpc-brute
}

function rdp-function {
	ip=$1; port=$2; folder=$3
	nmap $ip -p $port -Pn --script="*rdp* and not brute" > ${folder}rdp-nmap-scripts
	[ $brute = true ] && nmap ${ip} -p ${port} -Pn --script="rdp-brute"  > ${folder}nmap-rdp-brute
}
function netbios-function {
	ip=$1; port=$2; folder=$3
	nmblookup -A ${ip} > ${folder}/nmblookup
	nmap -sU -Pn --script="nb*" ${ip} > ${folder}/nmap-netbios-scripts
	enum4linux -a ${ip} > ${folder}/enum4linux
}
