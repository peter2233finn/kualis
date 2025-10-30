#!/bin/bash
# to scan results copied from a Qualys csv file                                                                                                                                                                                            
# enter targets in the order: ip port protocol (Seperated by spaces. Should be copied from csv file)                                                                                                                                       
# targets is the file which contains the data in the format: ip port protocol                                                                                                                                                              
                                                                                                                                                                                                                                           
# Error checking - check if root user                                                                                                                                                                                                      
if [ "$(id -u)" -ne 0 ]; then                                                                                                                                                                                                              
        echo 'This script must be run by root' >&2                                                                                                                                                                                         
        exit 1                                                                                                                                                                                                                             
fi                            
quick="false"                                                                                                                                                                                                                            
export brute="false"
export jumpbox="false"
# Put user args into varables 
                          
# h - jb host
# u - jb user
# p - jp port
# i - jb identity file
while getopts jqa:o:f:c:h:u:p:i:t:b opts; do                                                                                                                                                                                                          
        case ${opts} in                                                                                                                                                                                                                    
                a) functionScript="${OPTARG}" ;;                                                                                                                                                                                           
                f) target="${OPTARG}" ;;                                                                                                                                                                                                   
                o) folder="${OPTARG}" ;;                                                                                                                                                                                                   
                c) customscripts="${OPTARG}" ;;                                                                                                                                                                                            
                t) forks="${OPTARG}" ;;                                                                                                                                                                                                    
                h) export jbhost="${OPTARG}" ;;                                                                                                                                                                                                    
                u) export jbuser="${OPTARG}" ;;                                                                                                                                                                                                    
                p) export jbport="${OPTARG}" ;;                                                                                                                                                                                                    
                i) export jbidentity="${OPTARG}" ;;                                                                                                                                                                                                    
                q) quick="true" ;;                                                                                                                                                                                                    
                j) export jumpbox="true" ;;                                                                                                                                                                                                    
                b) export brute="true" ;;                                                                                                                                                                                                    
        esac                                                                                                                                                                                                                               
done                                                                                                                                                                                                                          
 

################## START ERROR CHECKING ################## 

if [ "$jumpbox" = "true" ]; then
	errorstr=""
	e="false"
	[ -z $jbuser ] && errorstr+="for JumpBox, you must specify the user with -u\n" && e="true"
	[ -z $jbidentity ] &&  errorstr+="for JumpBox, you must specify the ssh private key with -i\n" && e="true"
	[ -z $jbhost ] &&  errorstr+="for JumpBox, you must specify the host with -h\n" && e="true"
	[ -z $jbport ] && errorstr+="for JumpBox, you must specify the port with -p The default should be 22.\n" && e="true"
	[ -z "$e" ] && printf "$errorstr" && exit
	echo "Attempting SSH connection with the command: \"ssh ${jbuser}@${jbhost} -p ${jbport} -i ${jbidentity}\""
	ssh -o ConnectTimeout=10 -q "${jbuser}"@"${jbhost}" -p "${jbport}" -i "${jbidentity}" exit
	connStatus=$?

	[ $connStatus -ne 0 ] &&  echo "There was a problem connecting to the jumpbox. Please ensure SSH is working with the public key. This key should not have a password." && exit
	[ $connStatus -eq 0 ] && (echo "Connection successful.")
fi

if [ "$quick" = "true" ]; then
	functionScript="actions.sh"                                                                                                                                                                                           
	customscripts="custom-scripts"                                                                                                                                                                                          
	forks=3                                                                                                                                                                                                    

fi

# Error checking - Ensure the correct args are set by the user                                                                                                                                                                             
if [ -z "$target"  ] || [ -z "$folder" ] || [ -z "$customscripts" ] || [ -z "$functionScript" ]; then                                                                                                                                      
	echo "usage: kualys -o (output) -f (list of targets in the format: IP Port Protocol) -c (config - this is the custom-scripts file) -a (functions script - this is the actions.sh file) -t (threads - how many hosts to scan at once"
	echo
	echo "on quick (-q) mode: kualys -q -o (output) -f (list of targets in the format: IP Port Protocol)"                                                                                                                                                                                                                                         
        exit                                                                                                                                                                                                                               
fi                                                                                                                                                                                                                                         
                                                                                                                                                                                                                                          
################## END ERROR CHECKING ################## 

# set the number of processes to 3 if not set by user                                                                                                                                                                                      
[ -z "$forks" ] && forks=3                                                                                                                                                                                                                 
 
echo "Using $forks threads. Brute force: $brute. SSH JumpBox: $jumpbox"

# Ensure directory exists.                                                                                                                                                                                                                 
mkdir "$folder" 2> /dev/null                                                                                                                                                                                                               
 
findunusedport(){
        while true; do
                port=$(shuf -i 1024-65000 -n 1)
                # Get list of open ports

                if [ -z "$(ss -tuln | awk 'NR>1 {print $5}' | cut -d':' -f2 | sort -n | uniq | grep -Ev '^$' | grep $port)" ]; then
                        echo $port
                        break
                fi
                sleep 1
        done
}

# fscan scans indevigual services, after they are sorted in the following code.                                                                                                                                                            
# fscan function takes the following parameters:                                                                                                                                                                                           
# fscan folderPath ip port
fscan(){
        local sshPID=$4
        local fport="$3"
        local fip="$2"
        local tmpFile="/tmp/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 33 ; echo '').pScan"
        local tmpFileCommand="/tmp/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 33 ; echo '').pScan"
        local localFolder="${1}"

        file="${localFolder}/${fileName}"

        # Find the service from the Nmap scan
        service=$(cat "${localFolder}/nmap"|grep -A 1 SERVICE|tail -n 1|awk '{print $3}'|tr "\t" " "|tr -d "?")


        # Create file with the commands to be run. Alter parameters using sed.
	touch $tmpFile

	# This will split the services. Eg ssl/https will call ssl and https seperatly. 
	# This is done as there are too many services that call ssl/service unaccounted for.
	
	# varible blacklistService is a regex of services that should not be split. Eg ssl/http is https.
	blacklistService="ssl/http"

	for splitService in $(echo $service | grep -Ev "${blacklistService}" | tr '/' ' '); do 
		echo "TRACKING: $splitService"
		grep -E "^${splitService}:" ${customscripts} | sed "s/XXIPXX/${fip}/g" | sed "s/XXPORTXX/${fport}/g" >> $tmpFile
	done
	grep -E "^${service}:" ${customscripts} | sed "s/XXIPXX/${fip}/g" | sed "s/XXPORTXX/${fport}/g" >> $tmpFile

        # Print to user the commands that will be run.
        if [ $(wc -l $tmpFile | awk '{print $1}') -eq 0 ]; then
                echo "This service was detected as ${service} does not have any pre-defined scripts."
                grep -E "^unmatched:" ${customscripts} | sed "s/XXIPXX/${fip}/g" | sed "s/XXPORTXX/${fport}/g" > $tmpFile
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
        #       echo "Currently running: $(cat "$tmpFileCommand" | grep -v "$functionScript")"
                chmod +x "$tmpFileCommand"


        done < "$tmpFile"
        cat "$tmpFileCommand"
        chmod +x "$tmpFileCommand"
        "$tmpFileCommand"

 	# kill the sshPID if necessary
        [ "$jumpbox" = "true" ] && kill -9 $sshPID 
}

declare -a PID=()
pidNum=0

# The following code iterates through each of the services.
# It will ensure there is ip, port, protocol.

# I think the following file is a lock, indicating when the script ends.
# if there is an early break and file is absent, it will break loop. If still present, it will continue
# added for early abort and can be controlled within the embedded loop within
kualysLock="/tmp/$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 16)"
touch $kualysLock
while [ -f "$kualysLock" ]; do
	rm $kualysLock
	cat "$target" | sort | uniq | grep -Ei --color=never "udp|tcp" | while read line; do
		ip=$(echo "$line" |awk '{print $1}' | xargs)
		port=$(echo "$line" |awk '{print $2}' | xargs)
		proto=$(echo "$line" |awk '{print $3}' | xargs)
		folderPath="${folder}/${ip}/${port}"
		ipPath="${folder}/${ip}"

		
		# half arsed fix for some stupid bug I cant figure out
		# 192.168.1.1 will turn into 92.168.1.1 for some reason after a number of forks
		# Spent hours on the problem and cant figure the fucking thing out. 
		# Had incedent where scanning and bruting out-of-scope IPs
		if [ -z "$(grep -E "^$ip" "$target" )" ]; then touch "$kualysLock"; break; fi
		
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


			if [ "$jumpbox" = "true" ]; then
				localPort=$(findunusedport)
				ssh "${jbuser}"@"${jbhost}" -p "${jbport}" -i "${jbidentity}" -L ${localPort}:${ip}:${port} -N &
				sshPID=$!
				sleep 3

				# SET IP TO LOOPBACK
				# PORT TO FREE PORT
				ip="127.0.0.1"
				port="$localPort"
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
					echo "Nmap udp scan for ip: $ip port: $port protocol: $proto";
					nmap -Pn -sV -sC -sU $ip -p $port >> "${folderPath}/nmap"
				fi

				# Multithreading function
				((pidNum++))

				
				# FSCAN IS FORKED HERE
				fscan "${folderPath}" "$ip" "$port" $sshPID &
				PID+=$!
				unset ip port proto folderPath ipPath 
				if [ $(( $pidNum % $forks )) -eq 0 ]; then
					# Wait for all processes to finish
					for process in ${PID[@]}; do
						tail --pid=$process -f /dev/null
					done
					declare -a PID=()
					pidNum=0
				fi
			fi
		else
			echo "Target ${ip} on port ${port} has already been scanned. File is at: ${folderPath}"
		fi
	done

	# check if all hosts are scanned.
	# Exit once they are.
	rm "$kualysLock"
	cat "$target" | sort | uniq | grep -Ei --color=never "udp|tcp" | while read line; do
		ip=$(echo "$line" |awk '{print $1}' | xargs)
		port=$(echo "$line" |awk '{print $2}' | xargs)
		nmapPath="${folder}/${ip}/${port}/nmap"
		if [ ! -f "$nmapPath" ]; then 
			echo "Rescanning $nmapPath"
			touch "$kualysLock"
			break
		fi
		
	done
		
done
# Since it is run by root, it may not be possible to read as a normal user.
# change permissions to 777.
chmod -R 777 "${folder}"

# print summary.
printf "\n\n========================================================\nScan ran sucessfully. Here are the results: \n" 
