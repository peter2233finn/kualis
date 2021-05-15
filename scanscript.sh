sudo rm /tmp/nmapTempFile /tmp/nmapOpenPorts

# Make directory for each host scanned
function makeScanDir(){
	mkdir $1 2> /dev/null
	echo "$1/$2-$3"
}

# FTP scan
function ftpScan(){
	ip=$1;port=$2
	nmapftpdir=$(makeScanDir $ip $port "ftpscan")
	nmap --script="ftp*" -p $port $ip > $nmapftpdir
}

# HTTP/SSL scan
function httpScan(){
	ip=$1;port=$2
	dirbdir=$(makeScanDir $ip $port "dirb")
	nmaphttpdir=$(makeScanDir $ip $port "nmap-http")
	niktodir=$(makeScanDir $ip $port "nikto")
	sslscandir=$(makeScanDir $ip $port "sslscan")
	wpscandir=$(makeScanDir $ip $port "wpscan")

	# check if http or httos by whether it ends with port 80 or 443
	protocol="http://";if [[ "$port" == *"443" ]]; then protocol="https://"; fi

	# Proceed with scans
	gobuster dir -x "php,html,jsp,jpg" -w /usr/share/dirb/wordlists/big.txt --wildcard -u "$protocol"$ip:$port > $dirbdir
	nmap $ip -p $port --script="http*" > $nmaphttpdir
	nikto -h "$protocol""$ip":"$port" > $niktodir
	sslscan "$ip":"$port" > $sslscandir
	yes|wpscan --url "$protocol""$ip":"$port" > $wpscandir
}

# Decide what scan to run, depending on origional Nmap results
function portcheck(){
	ip=$1
	port=$2
	protocol=$3
	echo "Checking $ip on port $port""..."
	if [[ "$protocol" == *"http"* ]]; then echo "$ip contains http on $port. Running http scripts";httpScan $ip $port
	elif [[ "$protocol" == *"ssl"* ]]; then echo "$ip contains ssl on port $port. Running http scripts";httpScan $ip $port

	fi
}


# Read the file containing hosts
while read x; do
	# Scan host, All ports
	nmap -Pn -sV $x -p- -oG /tmp/nmapTempFile
	cat /tmp/nmapTempFile | grep -i open | sed 's/Ports: /\n/g'|tr "," "\n"| tr -d " "|grep -E "^[0-9]" | tr "\/" " " | awk '{print $1" "$4}' > /tmp/nmapOpenPorts
	cat /tmp/nmapOpenPorts >> /tmp/xxx
	clear; echo "The format should be: Port, Protocol. Does this look correct?"
	head /tmp/nmapOpenPorts

	# Iterate through all ports discovered
	while read p; do
		portcheck $x $p
	done < /tmp/nmapOpenPorts

	rm /tmp/nmapTempFile /tmp/nmapOpenPorts
done < "$*"
