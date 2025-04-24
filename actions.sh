#! /bin/bash
brute=true

function http-proxy-function {
	ip=$1; port=$2; folder=$3
	targets=(
	    "127.0.0.1"
	    "localhost"
	    "169.254.169.254"    # AWS metadata
	    "10.0.0.1"
	    "10.0.1.1"
	    "10.1.1.1"
	    "192.168.0.1"
	    "192.168.1.1"
	    "192.168.10.1"
	    "172.16.0.1"
	    "172.16.1.1"
	    "google.com"
	)

	for i in "${targets[@]}"; do
		echo "==== testing connection to: $i ===="
		echo "== https connection: =="
		timeout 3 curl -vv -k --proxy ${ip}:${port} https://$i

		echo "== http connection: =="
		timeout 3 curl -vv --proxy ${ip}:${port} http://$i
	done > ${folder}/http-proxy-to-addresses 2>&1
}

function http-function {
	ip=$1; port=$2; folder=$3
	curl -v "http://${ip}:${port}" > "${folder}curl-to-root-http" 2>&1
	curl -v "http://${ip}:${port}/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 15; echo)" > "${folder}curl-to-random-directory" 2>&1
	blacklist=$(cat "${folder}curl-to-random-directory" | grep '< HTTP/' | awk '{print $3}')
	timeout 1900 gobuster dir -k -u http://${ip}:${port} -w /usr/share/dirb/wordlists/common.txt -b ${blacklist} -o "${folder}gobuster" 2> /dev/null > /dev/null
	timeout 1900 nikto -port ${port} -Tuning 01234abcx57896 -host http://${ip} -Plugins headers outdated httpoptions robots origin_reflection put_del_test shellshock cgi docker_registry favicon apacheusers msgs report_text content_search parked paths tests 2>&1 > "${folder}nikto"
}

function isakmp-function {
        ip=$1; port=$2; folder=$3
        ike-scan ${ip} --dport ${port} -N -A > ${folder}/ike-scan 2>&1

        # Brute force IKE
        if [ ! -z "$(grep '0 returned handshake' "${folder}/ike-scan" |grep '1 returned notify')" ] && $brute; then
                for enc in $(seq 1 9); do 
                        for hash in $(seq 1 6);do 
                                for auth in $(seq 1 8);do 
                                        for group in $(seq 1 32);do 
						ikeconf="${enc},${hash},${auth},${group}"
      						echo "Following for settings: $ikeconf" >> ${folder}/ike-scan-brute
                                                ike-scan ${ip} --dport=${port} --trans=${ikeconf} >> ${folder}/ike-scan-brute 2>&1; 
                                        done
                                done
                        done
                done
        fi
}


function telnet-function {
	ip=$1; port=$2; folder=$3
	nmap -Pn ${ip} -p ${port} --script "telnet* and not brute" > "${folder}/nmap-telnet-no-brute" 2>&1
	[ $brute = true ] && nmap -Pn ${ip} -p ${port} -sV --script="telnet-brute"  > "${folder}nmap-telnet-brute-force" 2> /dev/null
}


function ssh-function {
	ip=$1; port=$2; folder=$3
	ssh-audit ${ip} -p ${port} > "${folder}ssh-audit" 2>&1
	nmap -Pn ${ip} -p ${port} -sV --script="ssh* and not brute"  > "${folder}nmap-ssh-no-brute"
	[ $brute = true ] && nmap -Pn ${ip} -p ${port} -sV --script="ssh-brute"  > "${folder}nmap-ssh-brute-force"
}

function https-function {
	ip=$1; port=$2; folder=$3
	curl --insecure -v "https://${ip}:${port}" > "${folder}curl-to-root" 2>&1
	curl --insecure -v "https://${ip}:${port}/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 15; echo)" > "${folder}curl-to-random-directory" 2>&1
	blacklist=$(cat "${folder}curl-to-random-directory" | grep '< HTTP/' | awk '{print $3}')
	
	timeout 1900 gobuster dir -k -u https://${ip}:${port} -b ${blacklist} -w /usr/share/dirb/wordlists/common.txt -o "${folder}gobuster" 2> /dev/null > /dev/null
	timeout 1900 nikto -port ${port} -Tuning 01234abcx57896 -host https://${ip} -Plugins headers outdated httpoptions robots origin_reflection put_del_test shellshock cgi docker_registry favicon apacheusers msgs report_text content_search parked paths tests 2>&1 > "${folder}nikto"
	
}

function ssl-function {
	ip=$1; port=$2; folder=$3
	sslscan --no-colour ${ip}:${port} > "${folder}sslscan"
}

function smtp-function {
	ip=$1; port=$2; folder=$3
	timeout 60 sendmail -t test@test.com -f test@test.com -s ${ip} -u "Testing SMTP Relay" 2>&1 > "${folder}SMTP-Relay-test"
	nmap ${ip} -p ${port} --script="*smtp* and not brute" -Pn  > "${folder}nmap-smtp-scripts" 2>&1
	[ $brute = true ] && nmap ${ip} -p ${port} --script="smtp-brute" -Pn  > "${folder}nmap-smtp-brute-scripts" 2> /dev/null
	smtp-user-enum -t ${ip} -p ${port} -U /usr/share/wordlists/common-snmp-community-strings.txt  > "${folder}smtp-user-enum" 2>&1
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
	nmap ${ip} -p ${port} -Pn --script="mysql* and not brute" > ${folder}nmap-mysql-scripts 2>/dev/null
	[ $brute = true ] && nmap ${ip} -p ${port} -Pn --script="mysql-brute" > ${folder}nmap-mysql-brute 2> /dev/null
	[ $brute = true ] && timeout 9000 hydra -L /usr/share/wordlists/usernames.txt -P /usr/share/wordlists/rockyou.txt ${ip} mysql -I -s ${port} -o ${folder}mysql-hydra 2> /dev/null
}

function telnet-function {
	ip=$1; port=$2; folder=$3
	nmap ${ip} -p ${port} -Pn --script="*telnet* and not brute"  > ${folder}nmap-script-telnet
	[ $brute = true ] && nmap ${ip} -p ${port} -Pn --script="telnet-brute"  > ${folder}nmap-telnet-brute

}

function unknown-function {
	ip=$1; port=$2; folder=$3
	nmap -Pn -sV -sC ${ip} -p ${port} --script="*" > ${folder}nmap-unknown 2>&1
	nmap -Pn -sV -sC ${ip} -p ${port} --version-all > ${folder}nmap-all-probes 2>&1
	curl --insecure https://${ip}:${port} > ${folder}unknown-curl-https 2>&1
	curl http://${ip}:${port} > ${folder}unknown-curl-http 2>&1
}

function msrcp-function { 
	ip=$1; port=$2; folder=$3
	timeout 300 rpcdump.py ${ip} > ${folder}rpcdump-without-port 2>&1
	timeout 300 rpcdump.py ${ip} -p ${port} > ${folder}rpcdump-to-port 2>&1
}

function mssql-function {
	ip=$1; port=$2; folder=$3
	nmap ${ip} -p ${port} -Pn --script="ms-sql* and not brute" > ${folder}/mssql-nmap-scripts 2>&1
	[ $brute = true ] && nmap ${ip} -p ${port} -Pn --script="ms-sql-brute" > ${folder}/mssql-brute-nmap 2>&1
}

function microsoft-ds-function {
	ip=$1; port=$2; folder=$3
	nmap -sV -sC ${ip} -p ${port} --script="smb*" -Pn > ${folder}smb-nmap-scripts 2>&1
	timeout 60 nbtscan -v -r ${ip} > ${folder}nbtscan 2>&1
	[ $brute = true ] && timeout 9000 hydra -t 1  -f -l administrator -P /usr/share/wordlists/rockyou.txt $ip smb -o ${folder}/smb-hydra 2> /dev/null
}


function ftp-function {
	ip=$1; port=$2; folder=$3
	nmap -sV -sC -Pn ${ip} -p ${port} --script="*ftp* and not brute" > ${folder}ftp-nmap-scripts 2>&1
	[ $brute = true ] && nmap -sV -sC -Pn ${ip} -p ${port} --script="ftp-brute" > ${folder}ftp-nmap-scripts 2> /dev/null
}

function dns-function {
	ip=$1; port=$2; folder=$3
	nmap $ip -p $port -Pn --script="dns* and not brute" > ${folder}nmap-dns 2>&1
 	[ $brute = true ] && nmap $ip -p $port -Pn --script="dns-brute" > ${folder}dns-brute-nmap 2>&1

}

function rpc-function {
	ip=$1; port=$2; folder=$3
	nmap $ip -p $port -Pn --script="*rpc* and not brute" > ${folder}rpc-nmap-scripts 2>&1
	[ $brute = true ] && nmap ${ip} -p ${port} -Pn --script="rpcap-brute"  > ${folder}rpc-brute-nmap 2>&1
}

function rdp-function {
	ip=$1; port=$2; folder=$3
	nmap $ip -p $port -Pn --script="*rdp*" > ${folder}rdp-nmap-scripts 2>&1
}
function netbios-function {
	ip=$1; port=$2; folder=$3
	nmblookup -A ${ip} > ${folder}/nmblookup 2>&1
	nmap -sU -Pn --script="nb*" ${ip} > ${folder}/nmap-netbios-scripts 2>&1
	enum4linux -a ${ip} > ${folder}/enum4linux 2>&1
}
