#!/bin/bash

#TODO 
# - Add *proper* support for online/offline dylib provision 
# - Add support for optional vervosity

NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)

#Switches 
#TODO: use proper options to change the swithces from the command line
removePlugIns=false
useLocalCopy=true
cleanUpEnabled=true
logEnabled=false

workDirectory=/tmp/iInject

#Clean up function definition
cleanUp () {

	if [ "$cleanUpEnabled" = true ]
	then
		printf "${NORMAL}%s${NORMAL}\n" "Cleaning up work directory "$workDirectory" "
		echo "rm -rf "$workDirectory""	
		rm -rf "$workDirectory"
	fi	
}

checkProvisioning (){
	
	#Get iDevice UUID
	iDevice=$(idevice_id -l)

	#Check that iDevice was connected
	if [ "$?" -ne "0" ]
	then
		printf "${RED}%s${NORMAL}\n" "Error while checking provisioning, the target iDevice needs to be connected!"
		exit 1
	fi

	#Check that provision profile, private key and certificate are already installed
	if [ -f ~/.isign/isign.mobileprovision ] && [ -f ~/.isign/certificate.pem ] && [ -f ~/.isign/key.pem ]
	then	
		grep -i "$iDevice"  ~/.isign/isign.mobileprovision >> "$debugDir" 2>&1
		#Check that current provision profile include target iDevice
		if [ "$?" -eq "0" ]
		then
			#No need for new provision profile
			printf "${GREEN}%s${NORMAL}\n" "Provisioning profile correctly installed"
			return 0
		fi
	fi

	printf "${RED}%s${YELLOW}\n%s\n%s${NORMAL}\n" "A new provision profile is needed, please use one of the provided helper scripts:" "For paid account -> genProvisioningProfileDev <AppleID> <Password> <Device UUID>" "For Free account -> genProvisioningProfileFree <AppleID> <Password> <Device UUID> "
}

#Main script start

#Verify arguments
if [ $# -lt "2" ] 
then
	printf "${RED}%s${NORMAL}\n" "Usage: "$0" <IPA File> <Dylib File>"
	exit 1
fi

ipaFile="$1"
dylibFile="$2"
dylibName=$(basename "$dylibFile")
ipaFilename=$(basename -s .ipa "$ipaFile")
ipaDirname=$(dirname "$ipaFile")

#Set up Logging
if [ "$logEnabled" = true ]
then
	debugDir=$(pwd)/"iInject.log"
	printf "${GREEN}%s${NORMAL}\n" "Log is going to be saved in ""$debugDir"
else
	debugDir="/dev/null"
fi

#Start log
echo `date`" Embedding started" >> "$debugDir" 2>&1

#Verify that provisioning is installed
checkProvisioning

#Making work directory
mkdir "$workDirectory" >> "$debugDir" 2>&1

#Uncompressing IPA file
printf "${NORMAL}%s${NORMAL}\n" "Uncompressing "$ipaFilename" in "$workDirectory" "

unzip $ipaFile -d "$workDirectory"/"$ipaFilename" >> "$debugDir" 2>&1

if [ "$?" -eq "0" ]
then
	printf "${GREEN}%s${NORMAL}\n" "File "$ipaFilename" uncompressed correctly in "$workDirectory" "
else
	printf "${RED}%s${NORMAL}\n" "Error while uncompressing  "$ipaFilename" in "$workDirectory" "
	cleanUp	
	exit 1
fi

workDirectory="$workDirectory"/"$ipaFilename"

if [ "$removePlugIns" = true ]
then
	#Checking for PlugIns directory
	printf "${NORMAL}%s${NORMAL}\n" "Checking for PlugIns directory"
	
	if [ -d "$workDirectory"/Payload/*/PlugIns ]
	then
		printf "${NORMAL}%s${NORMAL}\n" "PlugIns directory found, it will be deleted"
		echo "rm -rf "$workDirectory"/Payload/*/PlugIns"	
		rm -rf "$workDirectory"/Payload/*/PlugIns
		
		if [ "$?" -eq "0" ]
		then
			printf "${GREEN}%s${NORMAL}\n" " "$workDirectory"/Payload/*/PlugIns deleted sucessfully"
		else
			printf "${RED}%s${NORMAL}\n" "Error while deleting "$workDirectory"/Payload/*/PlugIns"
			cleanUp
			exit 1
		fi

	fi
fi

#Getting Binary to be patched
binaryName=`file "$workDirectory"/Payload/*/* | grep -i mach | cut -d ":" -f1 | grep -vi dylib`
numberOfBinaries=`echo "$binaryName" | tr -s "\n" "|" | awk -F'|' '{print NF-1}'`

if [ $numberOfBinaries -gt 1 ]
then
	printf "${RED}%s${NORMAL}\n" "To many binaries files in the directory "$workDirectory"/Payload/*/*"
	echo "$binaryName"
	cleanUp
	exit 1 
fi

#Patch Binary
printf "${NORMAL}%s${NORMAL}\n" "Patching Binary "$binaryName" "

insert_dylib --strip-codesig --inplace @executable_path/"$dylibName" "$binaryName" >> "$debugDir" 2>&1

if [ "$?" -eq "0" ]
then
	printf "${GREEN}%s${NORMAL}\n" "Binary "$binaryName"  patched sucessfully"
else
	printf "${RED}%s${NORMAL}\n" "Error while patching binary "$binaryName""
	cleanUp
	exit 1 
fi

# Gadget obtention
binaryDirectory=$(dirname "$binaryName")

if [ "$useLocalCopy" = false ]
then
#Download Fridagadget in the right directory
	printf "${NORMAL}%s${NORMAL}\n" "Downloading Fridagadget in  $binaryDirectory/ "

	curl https://build.frida.re/frida/ios/lib/FridaGadget.dylib --output "$binaryDirectory"/FridaGadget.dylib

	if [ "$?" -eq "0" ]
	then
		printf "${GREEN}%s${NORMAL}\n" " Gadget downloaded sucessfully"
	else
		printf "${RED}%s${NORMAL}\n" "Error while downloading Gadget"
		cleanUp
		exit 1 
	fi
else
# Use local copy of the Gadget
	printf "${NORMAL}%s${NORMAL}\n" "Coping local gadget $dylibFile to  $binaryDirectory/ "

	cp "$dylibFile" "$binaryDirectory"/ >> "$debugDir" 2>&1
	
	if [ "$?" -eq "0" ]
	then
		printf "${GREEN}%s${NORMAL}\n" "Gadget copied sucessfully"
	else
		printf "${RED}%s${NORMAL}\n" "Error while coping Gadget"
		cleanUp
		exit 1 
	fi

fi


#Adjusting direcorties before ziping

currPath=`pwd`

cd "$workDirectory"

#Creating new IPA
printf "${NORMAL}%s${NORMAL}\n" "Creating new IPA file in "$workDirectory"/"$ipaFilename"-patched.ipa"

zip -r "$ipaFilename"-patched.ipa Payload/ >> "$debugDir" 2>&1

if [ "$?" -eq "0" ]
then
	printf "${GREEN}%s${NORMAL}\n" ""$workDirectory"/"$ipaFilename"-patched.ipa created sucessfully"
else
	printf "${RED}%s${NORMAL}\n" "Error while creating "$workDirectory"/"$ipaFilename"-patched.ipa"
	cleanUp	
	exit 1 
fi

#Signing new IPA
printf "${NORMAL}%s${NORMAL}\n" "Signing IPA file "$workDirectory"/"$ipaFilename"-patched.ipa"

isign -v -o "$ipaFilename"-patched-isigned.ipa "$ipaFilename"-patched.ipa >> "$debugDir" 2>&1

if [ "$?" -eq "0" ]
then
	printf "${GREEN}%s${NORMAL}\n" ""$workDirectory"/"$ipaFilename"-patched-isigned.ipa created sucessfully"
else
	printf "${RED}%s${NORMAL}\n" "Error while signing "$workDirectory"/"$ipaFilename"-patched.ipa"
	cleanUp	
	exit 1 
fi

#Installing signed IPA
printf "${NORMAL}%s${NORMAL}\n" "Installing IPA file "$ipaFilename"-patched-isigned.ipa"

ideviceinstaller -i "$ipaFilename"-patched-isigned.ipa | tee -a "$debugDir"

if [ "$?" -eq "0" ]
then
	printf "${GREEN}%s${NORMAL}\n" ""$ipaFilename"-patched-isigned.ipa installed sucessfully"
else
	printf "${RED}%s${NORMAL}\n" "Error while installing "$ipaFilename"-patched-isigned.ipa"
	cleanUp	
	exit 1 
fi

cd "$currPath"

cleanUp

exit 0 
