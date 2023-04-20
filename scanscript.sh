# to scan results copied from a Qualys csv file
# enter targets in the order: ip port protocol (Seperated by spaces. Should be copied from csv file)

# targets is the file which contains the data in the format: ip port protocol
target="targets.txt"
folder="scan-results"


if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
        exit 1
fi
mkdir "$folder"

cat "$target" | sort | uniq | while read line; do
        ip=$(echo "$line" |awk '{print $1}')
        port=$(echo "$line" |awk '{print $2}')
        proto=$(echo "$line" |awk '{print $3}')

        # testing
        #echo "recieved: ip: $ip port: $port protocol:$proto";

        if [ ! -z $proto ]; then
                folderPath="${folder}/${ip}-${port}"

                if [ ! -f "$folderPath" ]; then
                        if [ "$proto" = "tcp" ]; then
                        echo "TCP scanning: ip: $ip port: $port protocol:$proto";
                                echo "TCP scanning: $ip"
                                nmap -sV -sC $ip -p $port >> "${folderPath}"

                        elif [ "$proto" = "udp" ]; then
                                echo "UDP scanning: ip: $ip port: $port protocol:$proto";
                                nmap -sV -sC -sU $ip -p $port >> "${folderPath}"
                        fi
                fi
        fi
done
chmod 777 "${folder}/*"
