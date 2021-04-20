sudo rm /tmp/nmapTempFile /tmp/nmapOpenPorts
function makeScanDir(){
	mkdir $1 2> /dev/null
	echo "$1/$2-$3"
}

function ftpScan(){
	ip=$1;port=$2
	nmapftpdir=$(makeScanDir $ip $port "ftpscan")
	nmap --script="ftp*" -p $port $ip > $nmapftpdir
}
function httpScan(){
	ip=$1;port=$2
	dirbdir=$(makeScanDir $ip $port "dirb")
	nmaphttpdir=$(makeScanDir $ip $port "nmap-http")
	niktodir=$(makeScanDir $ip $port "nikto")
	sslscandir=$(makeScanDir $ip $port "sslscan")

	# check if http or httos by whether it ends with port 80 or 443
	protocol="http://";if [[ "$port" == *"443" ]]; then protocol="https://"; fi

	# Proceed with scans
	gobuster dir --wildcard -x "php,html" -w /usr/share/dirb/wordlists/big.txt --url "$protocol"$ip:$port > $dirbdir
	nmap $ip -p $port --script="http*" > $nmaphttpdir
	nikto -h "$protocol""$ip":"$port" > $niktodir
	sslscan "$protocol""$ip":"$port" > $sslscandir
}

function portcheck(){
	ip=$1
	port=$2
	protocol=$3
	echo "Checking $ip on port $port""..."
	if [[ "$protocol" == *"http"* ]]; then echo "$ip contains http on $port. Running http scripts";httpScan $ip $port
	elif [[ "$protocol" == *"ssl"* ]]; then echo "$ip contains ssl on port $port. Running http scripts";httpScan $ip $port

	fi
}

function formatUrl(){
	tmp1=$(printf $1|sed 's/https:\/\///g')
	tmp2=$(printf $tmp1|sed 's/http:\/\///g')
	tmp1=$(printf $tmp2|sed 's/\///g')
	tmp2=$(printf $tmp1|sed 's/www\.//g')
	echo $tmp2
}

while read y; do
	# Format if its a URL. Will not work with http, https or www. or with a /
	x=$(formatUrl $y)
	nmap -p- -Pn -sV $x -oG /tmp/nmapTempFile
	cat /tmp/nmapTempFile | grep -i open | sed 's/Ports: /\n/g'|tr "," "\n"| tr -d " "|grep -E "^[0-9]" | tr "\/" " " | awk '{print $1" "$4}' > /tmp/nmapOpenPorts
	cat /tmp/nmapOpenPorts >> /tmp/xxx
	clear; echo "The format should be: Port, Protocol. Does this look correct?"

	while read p; do
		portcheck $x $p
	done < /tmp/nmapOpenPorts

	rm /tmp/nmapTempFile /tmp/nmapOpenPorts
done < "$*"
