#!/bin/bash

#TODO 
# - Add support for Arbitrary dylibs
# - Add *proper* support for online/offline dylib provision 
# - Add support for optional vervosity

NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)

removePlugIns=true
useLocalCopy=true
cleanUpEnabled=false

debugDir=/dev/null
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

#Main script start

mkdir "$workDirectory"
if [ $# -eq "0" ] 
then
	printf "${RED}%s${NORMAL}\n" "Usage: "$0" <IPA File>"
	cleanUp
	exit 1
fi

ipaFile=$1
ipaFilename=$(basename -s .ipa "$ipaFile")
ipaDirname=$(dirname "$ipaFile")
#ipaFilename=`echo $ipaFile  | sed -n "/".ipa"/s/".ipa"//p"`

#Uncompressing IPA file
printf "${NORMAL}%s${NORMAL}\n" "Uncompressing "$ipaFilename" in "$workDirectory" "

unzip $ipaFile -d "$workDirectory"/"$ipaFilename" > "$debugDir"

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

'/home/leandro/UNI/RP2/Tools/insert_dylib/insert_dylib/main' --strip-codesig --inplace @executable_path/FridaGadget.dylib "$binaryName"

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
	printf "${NORMAL}%s${NORMAL}\n" "Downloading Fridagadget in  "$binaryDirectory/" "

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
	printf "${NORMAL}%s${NORMAL}\n" "Coping local gadget to  "$binaryDirectory/" "
	cp '/home/leandro/UNI/RP2/Tools/iInject/FridaGadget.dylib' "$binaryDirectory"/
fi

#Adjusting direcorties before ziping

currPath=`pwd`

cd "$workDirectory"

#Creating new IPA
printf "${NORMAL}%s${NORMAL}\n" "Creating new IPA file in "$workDirectory"/"$ipaFilename"-patched.ipa"

zip -r "$ipaFilename"-patched.ipa Payload/ > "$debugDir"

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

isign -o "$ipaFilename"-patched-isigned.ipa "$ipaFilename"-patched.ipa

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

ideviceinstaller -i "$ipaFilename"-patched-isigned.ipa

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
