require "spaceship"

if ARGV.length < 3
	print "Script Usage : ruby genProvisionProfile.rb <user> <password> <iDevice UUID>\n"
	exit(1)
else
	user = ARGV[0]
	pass = ARGV[1]
	iDevice = ARGV[2]
end

#TODO: Validate arguments...

#Login to developer portals
Spaceship::Portal.login(user, pass)

#Create new key pair for this project
csr, pkey = Spaceship::Portal.certificate.create_certificate_signing_request

#Save private key
File.write("key.pem", pkey)

#Create certificate
Spaceship::Portal.certificate.development.create!(csr: csr)

#TODO: If maximum ammount of certificates reached revoke the last one...
#Spaceship::Portal.certificate.development.all.first.revoke!

#Get newest certifiate
cert = Spaceship::Portal.certificate.development.all.first

#Save certificate
File.write("certificate.pem", cert.download)

#Register new device
Spaceship::Portal.device.create!(name: "iDevice", udid: iDevice)

#TODO: Support when maximum device limitation reached.

# Create a new provisioning profile with all devices (by default)
profile = Spaceship::Portal.provisioning_profile.development.create!(bundle_id: "nl.iInject.*", certificate: cert, name: "new"+iDevice)

newProfile = Spaceship::Portal.provisioning_profile.all.first

#Print the status of the profile
#puts newProfile.valid?
#puts newProfile.certificate_valid?

if !(newProfile.valid?)
	print "There was a problem with the provisioning generation\n"
	exit(1)
elsif !(newProfile.certificate_valid?)
	print "There was a problem with the provisioning generation\n"
	exit(1)
end 

# Store the new profile on the filesystem
File.write("isign.mobileprovision", newProfile.download)
