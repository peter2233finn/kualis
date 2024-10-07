#!/bin/bash
# to scan results copied from a Qualys csv file
# enter targets in the order: ip port protocol (Seperated by spaces. Should be copied from csv file)
# targets is the file which contains the data in the format: ip port protocol

# Error checking - check if root user
if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
        exit 1
fi

# Put user args into varables
while getopts a:o:f:c:t: opts; do
        case ${opts} in
                a) functionScript="${OPTARG}" ;;
                f) target="${OPTARG}" ;;
                o) folder="${OPTARG}" ;;
                c) customscripts="${OPTARG}" ;;
                t) forks="${OPTARG}" ;;
        esac
done

# Error checking - Ensure the correct args are set by the user
if [ -z "$target"  ] || [ -z "$folder" ] || [ -z "$customscripts" ] || [ -z "$functionScript" ]; then
	echo "usage: kualys -o (output) -f (list of targets in the format: IP Port Protocol) -c (config - this is the custom-scripts file) -a (functions script - this is the actions.sh file) -t (threads - how many hosts to scan at once)"
        exit
fi

# set the number of processes to 3 if not set by user
[ -z "$forks" ] && forks=3

# Ensure directory exists.
mkdir "$folder" 2> /dev/null

# fscan scans indevigual services, after they are sorted in the following code.
# fscan function takes the following parameters:
# fscan folderPath ip port
fscan(){
        port="$3"
        ip="$2"
        tmpFile="/tmp/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 33 ; echo '').pScan"
        tmpFileCommand="/tmp/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 33 ; echo '').pScan"
        localFolder="${1}"
	

        file="${localFolder}/${fileName}"

        # Find the service from the Nmap scan
        service=$(cat "${localFolder}/nmap"|grep -A 1 SERVICE|tail -n 1|awk '{print $3}'|tr "\t" " "|tr -d "?")


        # Create file with the commands to be run. Alter parameters using sed.
        grep -E "^${service}:" ${customscripts} | sed "s/XXIPXX/${ip}/g" | sed "s/XXPORTXX/${port}/g" > $tmpFile
	
	# Print to user the commands that will be run.
	if [ $(wc -l $tmpFile | awk '{print $1}') -eq 0 ]; then
		echo "This service was detected as ${service} does not have any pre-defined scripts."
        	grep -E "^unmatched:" ${customscripts} | sed "s/XXIPXX/${ip}/g" | sed "s/XXPORTXX/${port}/g" > $tmpFile
	else
        	printf "\nThe service was detected as ${service}.\n\nwill run the following commands and save them in the files:\n\n"
	fi


	echo ". $functionScript" >> $tmpFileCommand
	while read l; do
		# load the function script to the payload

		# set varables
                fileName=$(echo ${l} | awk '{print $2}')
                command=$(echo ${l} | awk '{for (i=3; i<NF; i++) printf $i " "; print $NF}')
                sanitizedFile="$(echo ${localFolder}/${fileName} | sed 's/\//\\\//g')"
                sanitizedFolder="$(echo ${localFolder} | sed 's/\//\\\//g')\/"
		
                echo "${command}" | grep 'XXFILEXX'   | sed "s/XXFILEXX/${sanitizedFile}/g" >> $tmpFileCommand
                echo "${command}" | grep 'XXFOLDERXX' | sed "s/XXFOLDERXX/${sanitizedFolder}/g" >> $tmpFileCommand
	#	echo "Currently running: $(cat "$tmpFileCommand" | grep -v "$functionScript")"
		chmod +x "$tmpFileCommand"
		

        done < "$tmpFile"
	cat "$tmpFileCommand"
	chmod +x "$tmpFileCommand"
	"$tmpFileCommand"
}

declare -a PID=()
pidNum=0

# The following code iterates through each of the services.
# It will ensure there is ip, port, protocol.
cat "$target" | sort | uniq | while read line; do
        ip=$(echo "$line" |awk '{print $1}')
        port=$(echo "$line" |awk '{print $2}')
        proto=$(echo "$line" |awk '{print $3}')
       	folderPath="${folder}/${ip}/${port}"
	ipPath="${folder}/${ip}"

	mkdir "${ipPath}" 2> /dev/null
	mkdir "${folderPath}" 2> /dev/null

	echo "============================================================="
        # Check if it has already been scanned. This is done by checking if an nmap file is present.
	if [ ! -f "${folderPath}/nmap" ]; then
		echo "Target: $ip on port $port ($proto)"
        	# Dig to check any DNS information.
		if [ ! -f "${ipPath}/dns-dig" ]; then
        		dig -x $ip > "${ipPath}/dns-dig" 2>&1
        		host $ip > "${ipPath}/dns-host" 2>&1
        		whois $ip > "${ipPath}/whois" 2>&1
		fi

        	# Skip if the protocol is not present. 
        	# This is the final variable after ip and port, so if it is not present then skip it.  
        	if [ ! -z $proto ]; then
                        # Sort if tcp or udp, this will determine the nmap scan.
                        # If not tcp or udp, then skip.
                        if [ "$proto" = "tcp" ]; then
                        echo "Nmap tcp scan for ip: $ip port: $port protocol: $proto";
                                nmap -Pn -sV -sC $ip -p $port >> "${folderPath}/nmap"

                        elif [ "$proto" = "udp" ]; then
                                echo "nmap udp scan for ip: $ip port: $port protocol: $proto";
                                nmap -Pn -sV -sC -sU $ip -p $port >> "${folderPath}/nmap"
                        fi

			# Multithreading function
			((pidNum++))

			# FSCAN IS FORKED HERE
			fscan ${folderPath} $ip $port 
        		PID+=$!
			if [ $(( $pidNum % $forks )) -eq 0 ]; then
                		# Wait for all processes to finish
                		for p in ${PID[@]}; do
                        		tail --pid=$p -f /dev/null
                		done
				declare -a PID=()
        		fi
			sleep 1
		fi
	else
		echo "Target ${ip} on port ${port}  has already been scanned. File is at: ${folderPath}"
	fi
done

# Since it is run by root, it may not be possible to read as a normal user.
# change permissions to 777.
chmod -R 777 "${folder}"

# print summary.
printf "\n\n========================================================\nScan ran sucessfully. Here are the results: \n"
ls "${folder}" |tr "-" " "|awk '{print $1}'|sort|uniq -c|sort|awk '{print "There are: "$1" ports scanned for the IP address: " $2}'
