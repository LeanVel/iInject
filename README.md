# iInject
Tool to automate the process of embedding dynamic libraries into iOS applications from GNU/Linux.
The tool should work for non-jailbroken iOS devices running iOS 9 or higher. 

This command line tool takes as an input an iOS application (.ipa) file and a dynamic library file (.dylib).
It then implements the executable modification, code signing, and application deployment in an automated fashion.

Requirements
============

- IPA files without encryption nor Fairplay protection
- ZIP/UNZIP
- gcc
- Python
- insert_dylib
- iSign
- curl
- libimobiledevice / ideviceinstaller
- **Valid provisioning profile** - See Helper Scripts for more info.

libimobiledevice / ideviceinstaller
-----------------------------------
#From Source
https://github.com/libimobiledevice/libimobiledevice

#RPM
```
  $ sudo dnf install libimobiledevice libimobiledevice-utils
```
#DEB
```
  $ sudo apt install libimobiledevice libimobiledevice-utils
```
More info @ http://www.libimobiledevice.org/

insert_dylib
------------
Since the master repository (https://github.com/Tyilo/insert_dylib) does not support Linux directly, we have forked it and made the modifications needed in order to port it to Linux. Our version of insert_dylib can be found in https://github.com/LeanVel/insert_dylib.

```
  $ git https://github.com/LeanVel/insert_dylib
  $ cd insert_dylib
  $ ./Install.sh
```

isign
-----
To successfully sign the iOS binaries after inserting the dylib, the signer needs to support signing from scrach. Since the master repository for iSign (https://github.com/saucelabs/isign) does not support this feature, iInject uses the version implemented by ryu2 (https://github.com/ryu2/isign). 

```
  $ git clone https://github.com/ryu2/isign
  $ cd isign
  $ sudo  python setup.py install
```  

iInject was tested using the version of iSign backed up in this repository https://github.com/LeanVel/isign

iInject Usage
=============
```
  $ ./iInject.sh <IPA File> <Dylib File>
```

# Helper Scripts
In this project we also include two scripts that automates the **__generation of the provisioning profile__** required in the code signing step. These helper scripts require the AppleID and password of the user, in combination with the UUID of the device. Depending on the type of account one of these scripts should be used.

Individual/Enterprise Developer Accounts
========================================

For this type of account, the script **genProvisioningProfileDev.rb** should be used. This script uses the library *spaceship* provided by the project [Fastlane](https://github.com/fastlane/fastlane/tree/master/spaceship) to contact the Apple Developer Portal API and generate a provisioning profile.

Requirements
------------
- ruby
- gem
- fastlane

Ruby and Gem installation
-------------------------

#RPM
```
  $ sudo dnf install ruby gem
```
#DEB
```
  $ sudo apt install ruby gem
```
Fastlane installation
---------------------

```
  $ sudo gem install fastlane
```

Usage
-----

```
  $ ./genProvisioningProfileDev.rb <user> <password> <iDevice UUID>
```


Free Apple Accounts
===================

For this type of account, the script **./genProvisioningProfileFree.sh** should be used. This script uses the curl and xmllint to contact the Apple Developer Portal API and generate a provisioning profile.

Requirements
------------
- curl
- xmllint

Curl and xmllint installation
-------------------------

#RPM
```
  $ sudo dnf install curl xmllint
```
#DEB
```
  $sudo apt install curl xmllint
```

Usage
-----

```
  $ ./genProvisioningProfileFree.sh <AppleID> <Password> <Device UUID>
```
