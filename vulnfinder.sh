#! /bin/bash
# 1 - issue
# 2 - initial grep. Will run Grep -R $2 folder
# 3+ - actions to grep. This will be added as " | grep $this"

folder="$1"

function simpleFind () {

        # find number of issues to grep
        lock=0
        toRun="grep -R \"$2\" $folder"
        for i in "$@"; do
                if [ $lock -gt 1 ]; then
                        toRun+=" | grep \"$i\""
                fi
                ((lock++))
        done
        bash -c "$toRun" > /tmp/vulnFinder.tmp

        if [ -s /tmp/vulnFinder.tmp ]; then
                printf "\n\n$1"
                cat /tmp/vulnFinder.tmp
        fi

        #grep -Ri "$folder" $2
}


simpleFind "INFO: SSH Version detected" "OpenSSH " "nmap-ssh-no-brute" 
simpleFind "LOW: Trace method allowed" "Access-Control-Allow-Methods" "curl-to-root"
simpleFind "INFO: Server header in use" "Server: " "curl-to-root"
