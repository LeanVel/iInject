#!/bin/bash

############### Overview ###############

# genProvisioningProfileFree.sh
# Script to generate a private key, certificate, and mobileprovision file used to be able to sign IPA files.
# The mobileprovision file is valid for 7 days, after this period the script has to be run again.
# Script dependencies: openssl, curl, xmllint. 


############### Verify arguments ###############
NORMAL=$(tput sgr0)
RED=$(tput setaf 1)


if [ $# -lt "3" ]
then
	printf "${RED}%s${NORMAL}\n" "Usage: "$0" <AppleID> <Password> <Device UUID>"
	exit 1
fi

APPLEID="$1"
PASSWORD="$2"
UUID="$3"

############### STATIC VALUES ###############

NEWLINE=$'\n'
APPIDKEY=ba2ec180e6ca6e6c6a542255453b24d6e6e5b2be0cc48bc1b0d8ad64cfe0228f
CLIENTID=XABBG36SBA

EPOCH=$(date +%s)
DEVICENAME=iDevice
GROUPID="group.testapp""$EPOCH"
IDENTIFIER="testapp""$EPOCH"
APPNAME="name testapp""$EPOCH"
 
############### WHERE TO STORE THE MOBILEPROVISION FILE AND CERTIFICATE ###############

outDir="$HOME/.isign/"

mkdir -p "$outDir"

privatekeydirectoryfile="$outDir""key.pem"
csrdirectoryfile="$outDir""csr.csr"
provisiondirectoryfile="$outDir""isign.mobileprovision"
certificatedirectoryfile="$outDir""certificate.pem"

if [ -f "$privatekeydirectoryfile" ]
then
	echo "Current private key in $HOME/.isign/ will be replaced"
	rm "$privatekeydirectoryfile"
fi

if [ -f "$csrdirectoryfile" ]
then
	echo "Current CSR in $HOME/.isign/ will be replaced"
	rm "$csrdirectoryfile"
fi

if [ -f "$provisiondirectoryfile" ]
then
	echo "Current Provisioning Profile in $HOME/.isign/ will be replaced"
	rm "$provisiondirectoryfile"
fi

if [ -f "$certificatedirectoryfile" ]
then
	echo "Current Certificate in $HOME/.isign/ will be replaced"
	rm "$certificatedirectoryfile"
fi

############### GENERATE KEYPAIR AND GENERATE CSR ###############


openssl genrsa -out "$privatekeydirectoryfile" 2048

openssl req -new -key "$privatekeydirectoryfile" -out "$csrdirectoryfile" -subj "/C=NL/ST=STATE/L=LOCAL/O=ORGANIZATION/CN=CN"

if [ -f "$csrdirectoryfile" ]
then
	CSR=$(cat $csrdirectoryfile)
else
	echo "CSR is not generated, check if openssl is properly installed"
	exit 1
fi


############### REQUEST 1 (AUTHENTICATE TO APPLE) ###############

POST1=$(curl --compressed -k -A "Xcode" --data "appIdKey="$APPIDKEY"&appleId="$APPLEID"&format=plist&password="$PASSWORD"&protocolVersion=A1234&userLocale=en_US" https://idmsa.apple.com/IDMSWebAuth/clientDAW.cgi --header "application/x-www-form-urlencoded")

MYACINFO=$(echo $POST1 | xmllint --format --xpath "string(//string[3]/text())" -)
RESPONSEID=$(echo $POST1 | xmllint --format --xpath "string(//string[5]/text())" -)

echo "1. authenticate to apple"
echo "$NEWLINE"


############### REQUEST 2 (GET TEAM INFORMATION) ###############

XML1="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>57A9D377-E345-4F2D-BF68-9623E4C23AA0</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"


POST2=$(curl --compressed -k -X POST -A "Xcode" --data "$XML1" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/listTeams.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)")

TEAMID=$(echo $POST2 | xmllint --format --xpath "string(//string[3]/text())" -)

echo "2. get team information"
echo "$NEWLINE"

############### REQUEST 3 (GET DEVICE INFORMATION) ###############


XML2="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>F22C5178-1655-4D7A-BE00-D18BBB97A5D6</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"

POST3=$(curl --compressed -k -X POST -A "Xcode" --data "$XML2" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/listDevices.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')

echo "3. check if device is already registered"
echo "$NEWLINE"

############### REQUEST 3B (ADD DEVICE INFORMATION IF NOT LISTED YET) ###############

XML2b="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>deviceNumber</key><string>"$UUID"</string><key>name</key><string>"$DEVICENAME"</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>B3BCBDE8-1CF9-4188-82E5-323DC5276798</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"

NEWDEVICE=$(echo $POST3 | xmllint --format --xpath "//*[text() = '$UUID']" -)

#If NEWDEVICE string is emtpy then we have to add it:
if [ -z "$NEWDEVICE" ]
then
	POST3b=$(curl --compressed -k -X POST -A "Xcode" --data "$XML2b" --cookie 		"myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/addDevice.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')
	echo "3b. registering device"
	echo "$NEWLINE"
fi


############### REQUEST 4 (List All Development Certificates) ###############


XML3="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>BCAB37D0-942A-43EE-BEE8-4BEB1B437513</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"

POST4=$(curl --compressed -k -X POST -A "Xcode" --data "$XML3" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/listAllDevelopmentCerts.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')

CERTNR=$(echo $POST4 | xmllint --format --xpath "string(//string[3]/text())" -)

echo "4. list current certificates"
echo "$NEWLINE"

############### REQUEST 4a (RevokeDevelopmentCert) ###############


XML3a="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>serialNumber</key><string>"$CERTNR"</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>6A4826ED-8DEC-41BD-96A9-2D7E0E99AFFF</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"

POST4a=$(curl --compressed -k -X POST -A "Xcode" --data "$XML3a" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/revokeDevelopmentCert.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')

echo "5. revoke certificate if present"
echo "$NEWLINE"

############### REQUEST 4b (SubmitDevelopmentCSR) ###############

# TODO CHANGE HARDCODED CSR

XML3b="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>csrContent</key><string>"$CSR"</string><key>machineId</key><string>CB6D337C-3D63-4523-AADE-6622234ABDA8</string><key>machineName</key><string>Cydia</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>4CDE3AA2-34B8-4878-9A86-14303F867108</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"


POST4b=$(curl --compressed -k -X POST -A "Xcode" --data "$XML3b" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/submitDevelopmentCSR.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')

echo "6. submit CSR"
echo "$NEWLINE"

############### REQUEST 4c (List All Development Certificates) ###############


XML3c="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>BCAB37D0-942A-43EE-BEE8-4BEB1B437513</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"

POST4c=$(curl --compressed -k -X POST -A "Xcode" --data "$XML3c" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/listAllDevelopmentCerts.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')


CERTIFICATE=$(echo $POST4c | xmllint --format --xpath "string(//data[1]/text())" -)
STARTTAGCERT="-----BEGIN CERTIFICATE-----"
ENDTAGCERT="-----END CERTIFICATE-----"

if [ -f "$certificatedirectoryfile" ]
then
	echo "certificate.pem is already present, please remove first"
	exit 1
else
	touch "$certificatedirectoryfile"
	echo "$STARTTAGCERT" > "$certificatedirectoryfile"
	echo "$CERTIFICATE" >> "$certificatedirectoryfile"
	echo "$ENDTAGCERT" >> "$certificatedirectoryfile"
fi

echo "7. Certificate.pem is stored"
echo "$NEWLINE"



############### REQUEST 5 (List App ID's) ###############

XML4="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>128D2644-1F31-40B6-A12B-7C95CE9212AE</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"


POST5=$(curl --compressed -k -X POST -A "Xcode" --data "$XML4" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/listAppIds.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')

SOMEAPPID=$(echo $POST6 | xmllint --format --xpath "string(//key[20]/text())" -)

echo "8. List current applications"
echo "$NEWLINE"

############### REQUEST 6 (List App Groups) ###############

XML5="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>37A70A0F-092F-45DE-9890-B1FB88708501</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"

POST6=$(curl --compressed -k -X POST -A "Xcode" --data "$XML5" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/listApplicationGroups.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')

echo "9. List current application groups"
echo "$NEWLINE"

############### REQUEST 7 (Add App Group) ###############

XML6="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>identifier</key><string>"$GROUPID"</string><key>name</key><string>"$APPNAME"</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>6F40E36A-46BF-4769-BA26-B18CDC785849</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"

POST7=$(curl --compressed -k -X POST -A "Xcode" --data "$XML6" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/addApplicationGroup.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')

ASSIGNEDGROUPID=$(echo $POST7 | xmllint --format --xpath "string(//string[1]/text())" -)

echo "10. Add new application group"
echo "$NEWLINE"

############### REQUEST 8 (Add App ID) ###############

XML7="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>"$SOMEAPPID"</key><true/><key>DTDK_Platform</key><string>ios</string><key>entitlements</key><array></array><key>identifier</key><string>"$IDENTIFIER"</string><key>name</key><string>"$APPNAME"</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>420A8681-4AF6-4150-9822-DF6F5A31637C</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"


POST8=$(curl --compressed -k -X POST -A "Xcode" --data "$XML7" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/addAppId.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')

APPID=$(echo $POST8 | xmllint --format --xpath "string(//string[1]/text())" -)

echo "11. Add new application to list"
echo "$NEWLINE"

############### REQUEST 9 (Assign App Group to App ID) ###############


XML8="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>appIdId</key><string>"$APPID"</string><key>applicationGroups</key><string>"$ASSIGNEDGROUPID"</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>4C961EFA-ADFD-471C-994D-7A34C2F94DD0</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"


POST9=$(curl --compressed -k -X POST -A "Xcode" --data "$XML8" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/assignApplicationGroupToAppId.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')
	
echo "12. Assign AppID to GroupID"
echo "$NEWLINE"

############### REQUEST 10 (GET PROVISION FILE) ###############


XML9="<?xml version="\""1.0"\"" encoding="\""UTF-8"\""?>"${NEWLINE}"<"'!'"DOCTYPE plist PUBLIC "\""-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd"\"">"${NEWLINE}"<plist version="\""1.0"\""><dict><key>DTDK_Platform</key><string>ios</string><key>appIdId</key><string>"$APPID"</string><key>teamId</key><string>"$TEAMID"</string><key>clientId</key><string>"$CLIENTID"</string><key>myacinfo</key><string>"$MYACINFO"</string><key>protocolVersion</key><string>QH65B2</string><key>requestId</key><string>8E9B4EFD-0658-4133-A65C-2B76A0173BB7</string><key>userLocale</key><array><string>en_US</string></array></dict></plist>"

POST10=$(curl --compressed -k -X POST -A "Xcode" --data "$XML9" --cookie "myacinfo="$MYACINFO"" https://developerservices2.apple.com/services/QH65B2/ios/downloadTeamProvisioningProfile.action?clientId=XABBG36SBA --header "Content-Type: text/x-xml-plist" --header "X-Xcode-Version: 7.0 (7A120f)" --header 'Expect:')


MOBILEPROVISIONFILE=$(echo $POST10 | xmllint --format --xpath "string(//data[1]/text())" -)

if [ -f "$provisiondirectoryfile" ]
then
	echo "isign.mobileprovision is already present, please remove first"
	exit 1
else
	echo "$MOBILEPROVISIONFILE" | base64 --decode > "$provisiondirectoryfile"
fi

echo "13. Download Provisioning Profile"
echo "$NEWLINE"
echo "DONE"
echo "$NEWLINE"












