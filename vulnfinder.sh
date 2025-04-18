#! /bin/bash

folder="$1"

function simpleFind () {
# This is a simple find function that will use grep -R with an initial value then any other values will grep this after

# 1 - issue
# 2 - initial grep. Will run Grep -R $2 folder
# 3+ - actions to grep. This will be added as " | grep $this"
	
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
		printf "\n\n$1\n"
		cat /tmp/vulnFinder.tmp
	fi
}

function regexFind () {
# This function will search via grep regex using -E option. It works the same way as the simpleFind function. 

# 1 - issue
# 2 - regex grep. Will run Grep -R -E $2 folder
# 3+ - additional actions to grep. This will be added as " | grep $this"
	
	# find number of issues to grep
	lock=0
	toRun="grep -R -E \"$2\" $folder"
	for i in "$@"; do
		if [ $lock -gt 1 ]; then
			toRun+=" | grep -E \"$i\""
		fi
		((lock++))
	done
	bash -c "$toRun" > /tmp/vulnFinder.tmp

	if [ -s /tmp/vulnFinder.tmp ]; then
		printf "\n\n$1\n"
		cat /tmp/vulnFinder.tmp
	fi
}


simpleFind "HIGH: The server accepts HTTP connections with code 200. may not redirect" "200 OK" "curl-to-root-http"
regexFind  "MEDIUM: The SSH server is using weak algorythms/hashes/mac" "algorithm to remove|\[fail\]" "ssh-audit"
simpleFind "LOW: Trace method allowed" "Access-Control-Allow-Methods" "curl-to-root"
simpleFind "INFO: SSH Version detected" "OpenSSH " "nmap-ssh-no-brute" 
simpleFind "INFO: Server header in use" "Server: " "curl-to-root"
