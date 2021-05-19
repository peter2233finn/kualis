# Make directory for each host scanned
function makeScanDir(){
	[ -d $1 ] || (mkdir $1; echo Making directory for: $1)
#	mkdir $1
	echo "$1/$2-$3"
}

function execute(){
	ip=$(echo "$*"|awk '{print $1}')
	port=$(echo "$*"|awk '{print $2}')
	cmd=$(echo "$*"|awk '{print $3}')
	directory="$(makeScanDir $ip $port $cmd)"
	cmd="$(printf "$*"|awk '{print $4" "$5" "$6" "$7" "$8" "$9" "$10" "$11" "$12" "$13" "$14" "$15}') > $directory"
	sp="\n===================================================================\n"
	printf "$sp executing: $cmd $sp Address: $ip Port: $port with command: $cmd $sp"|sed 's/>/ into directory: /g'|sed 's/  / /g'
	eval "$cmd"
}


# FTP scan
function ftpScan(){
	ip=$1;port=$2
	execute "$ip $port nmap nmap --script=\"ftp*\" -p $port $ip"
}

# HTTP/SSL scan
function httpScan(){
	ip=$1;port=$2
	echo "Starting http scan on: $ip and port $port"
	# check if http or httos by whether it ends with port 80 or 443
	protocol="http://";if [[ "$port" == *"443" ]]; then protocol="https://"; fi

	# Proceed with scans
	execute "$ip $port nikto nikto -h $protocol$ip:$port -maxtime 30m"
	execute "$ip $port nmap-http-scripts nmap $ip -p $port --script='http*'"
	execute "$ip $port gobuster gobuster dir -x 'php,html,jsp,jpg' -w /usr/share/dirb/wordlists/big.txt --wildcard -u $protocol$ip:$port"
	execute "$ip $port sslscan sslscan $ip:$port"
	execute "$ip $port wpscan yes|wpscan --url $protocol$ip:$port"
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
	# two tempoary files for nmap results.
	tmpFile=tmp1
	openports=tmp2
	tmp1="/tmp/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 25)"
	tmp2="/tmp/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 25)"

	# Scan host, All ports
	nmap -Pn -sV $x -p- -oG $tmp1
	cat $tmp1 | egrep -i "filtered|open" | sed 's/Ports: /\n/g'|tr "," "\n"| tr -d " "|grep -E "^[0-9]" | tr "\/" " " | awk '{print $1" "$4}' > $tmp2

	# Iterate through all ports discovered
	while read p; do
		portcheck $x $p
	done < $tmp2

done < "$*"
