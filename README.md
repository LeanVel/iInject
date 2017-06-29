# iInject
Tool to automate the process of embedding dynamic libraries into iOS applications from GNU/Linux.
The tool should work for non-jailbroken iOS devices running iOS 9 or higher. 

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
  $sudo apt install libimobiledevice libimobiledevice-utils
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

iInject was tested using the version of iSign backuped in this repository https://github.com/LeanVel/isign
