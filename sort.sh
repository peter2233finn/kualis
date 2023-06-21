# Put user args into varables
while getopts f:r:o: opts; do
        case ${opts} in
                f) target="${OPTARG}" ;;
                r) folder="${OPTARG}" ;;
                o) opt="${OPTARG}" ;;
        esac
done

[ -z ${target+x} ] && printf "usage: sort.sh -f (target file) -r (folder with results). \nNote that results are not necessary for options 1 and 2.\nIf \
you dont want to manually select an option each time, then this can be done with -o arguement.\n" && exit

if [ -z ${opt+x} ]; then
        echo "What do you want to do?"
        echo "1. Print in format: ip port/protocol"
        echo "2. Print in format: ip port protocol"
        echo "3. Check which targets have not been scanned."
        read opt
fi


[ $opt = "1" ] && cat "${target}"|grep -E -i "tcp|udp"|sort|uniq|awk '{print $1" "$2"/"$3}'
[ $opt = "2" ] && cat "${target}"|grep -E -i "tcp|udp"|sort|uniq|awk '{print $1" "$2" "$3}'

if [ "$opt" = "3" ]; then
        [ -z ${folder+x} ] && printf "usage: sort.sh -f (target file) -r (folder with results). \nTo use option 3 and 4, you must have the -r arguement.\n" && exit
        [ ! -d "${folder}" ] && printf "The results folder you selected in -r does not exist\n" && exit
        echo "testing if each target has been scanned."
        cat "${target}"|grep -E -i "tcp|udp"|sort|uniq|awk '{print $1"-"$2}' | while read x; do
                targetFile="${folder}/""$x"

                if [ ! -f "${targetFile}/nmap" ]; then
                        echo "NOT SCANNED: $(echo ${targetFile} | tr "-" " "|tr "/" " "|awk '{print "IP address: " $2 " on port: "$3}')"
                fi
        done
        echo "Done."


elif [ "$opt" = "4" ]; then echo "NOT IMPLEMENTED"; fi
