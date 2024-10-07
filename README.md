# A bash script designed to streamline penetration testing by automatically running tools on a given service. 
This script that will take in a previous TCP/UDP scan, and run a selection of tools depending on what service is detected by an Nmap scan. It will then create a directory tree of IP/port/scan-result.

For example, with the given file:
<br>1.1.1.1 80 tcp
<br>1.1.1.1 443 tcp
<br>1.1.1.1 8080 tcp
<br>...

the tool will run tools such as nikto, sslscan, gobuster ect. The tools that will be used are stored in the file called custom-scripts. This file is broken into three parts:
1. The first colum is the service as nmap detects is. For example, smtp, http or ssl/https

2. The second part is the name of the file that will be saved. For example, gobuster-directory.

3. The third and final part of the file contains the command. The XXPORTXX and XXIPXX will be replaced with the IP address and port number.

<br>The first part of the file can be created using a scanner such as Nmap or Masscan. 
<br>**masscan --top-ports=1000 -oG ScanResults.txt 192.168.0.0/24**
<br><br>Then formatting it to the input file by running the command:
<br>**grep open ScanResults.txt|tr "/" " "|awk '{print $4" "$7" "$9}'** > scanResults.txt
<br><br>This can then be run by the scanner
<br>**./scan.sh -o outputFolder -f scanResults.txt -c custom-scripts -a actions.sh -t 1**
<br><br>
When the scan is running or complete, the program sort.sh can be used to sort the results or check what has not yet been scanned. The execution format is as follows:<br>
**./sort.sh -f scanResults.txt -r outputFolder**<br>

Feel free to commit changes and additions. Im not a programmer by day, so please excuse the shoddy code.
