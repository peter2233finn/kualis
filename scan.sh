# to scan results copied from a Qualys csv file
# enter targets in the order: ip port protocol (Seperated by spaces. Should be copied from csv file)

# targets is the file which contains the data in the format: ip port protocol
target="targets.txt"
folder="scan-results"


if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
        exit 1
fi
mkdir "$folder" 2> /dev/null
fscan(){
        port="$3"
        ip="$2"
        tmpFile="/tmp/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 33 ; echo '').pScan"
        tmpFileCommand="/tmp/$(tr -dc A-Za-z0-9 </dev/urandom | head -c 33 ; echo '').pScan"
        folder="${1}"

        service=$(cat "${folder}/nmap"|grep -A 1 SERVICE|tail -n 1|awk '{print $3}'|tr "\t" " ")
        printf "==============================\nThe service was detected as: ${service}.\n\nwill run the following commands and save them in the files.\n"
        grep "$service" custom-scripts | sed "s/XXIPXX/${ip}/g" | sed "s/XXPORTXX/${port}/g" | awk '{for (i=3; i<NF; i++) printf $i " "; print $NF}'

        # get commands
        grep "$service" custom-scripts | sed "s/XXIPXX/${ip}/g" | sed "s/XXPORTXX/${port}/g" > $tmpFile

        while read l; do
                fileName=$(echo ${l} | awk '{print $2}')
                command=$(echo ${l} | awk '{for (i=3; i<NF; i++) printf $i " "; print $NF}')
                echo "${command} > ${folder}/${fileName} 2> /dev/null" > $tmpFileCommand
                sh "$tmpFileCommand"
        done < "$tmpFile"

        rm $tmpFile $tmpFileCommand

}


cat "$target" | sort | uniq | while read line; do
        ip=$(echo "$line" |awk '{print $1}')
        port=$(echo "$line" |awk '{print $2}')
        proto=$(echo "$line" |awk '{print $3}')

        # testing
        #echo "recieved: ip: $ip port: $port protocol:$proto";

        if [ ! -z $proto ]; then
                folderPath="${folder}/${ip}-${port}"
                mkdir "$folderPath" 2> /dev/null
                if [ ! -f "${folderPath}/nmap" ]; then
                        if [ "$proto" = "tcp" ]; then
                        echo "Nmap tcp scan for ip: $ip port: $port protocol: $proto";
                                nmap -sV -sC $ip -p $port >> "${folderPath}/nmap"

                        elif [ "$proto" = "udp" ]; then
                                echo "nmap udp scan for ip: $ip port: $port protocol: $proto";
                                nmap -sV -sC -sU $ip -p $port >> "${folderPath}/nmap"
                        fi
                        fscan ${folderPath} $ip $port
                        echo "fscan ${folderPath} $ip $port"
                fi
        fi
done
chmod -R 777 "${folder}"
printf "\n\n========================================================\nScan ran sucessfully. Here are the results: \n"
ls scan-results|tr "-" " "|awk '{print $1}'|sort|uniq -c|awk '{print "There are: "$1" ports scanned for the IP address: " $2}'
