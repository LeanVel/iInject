#!/bin/ruby
require "spaceship"

if ARGV.length < 3
	print "Usage :  ./genProvisionProfile.rb <user> <password> <iDevice UUID>\n"
	exit(1)
else
	user = ARGV[0]
	pass = ARGV[1]
	iDevice = ARGV[2]
end

#TODO: Validate arguments.

#Login to developer portals
Spaceship::Portal.login(user, pass)

#TODO: Check if there is currently install pricate key has a valid certificate.

#Create new key pair for this project
csr, pkey = Spaceship::Portal.certificate.create_certificate_signing_request

#Create Directory
FileUtils.mkdir_p "#{Dir.home}/.isign"

#Save private key
if (File.exists? "#{Dir.home}/.isign/key.pem")
	print "Removing exisitng private key\n"
	File.delete("#{Dir.home}/.isign/key.pem")
end 
print "Writing new private key\n"
File.write("#{Dir.home}/.isign/key.pem", pkey)

#TODO: If maximum ammount of certificates reached revoke the last one...
certs = Spaceship::Portal.certificate.development.all
if (certs.length == 1)
	certs.first.revoke!
end	

#Create certificate
Spaceship::Portal.certificate.development.create!(csr: csr)

#Get newest certifiate
cert = Spaceship::Portal.certificate.development.all.first

#Save certificate
if (File.exists? "#{Dir.home}/.isign/certificate.pem")
	print "Removing exisitng certificate\n"
	File.delete("#{Dir.home}/.isign/certificate.pem")
end 

print "Writing new certificate\n"
File.write("#{Dir.home}/.isign/certificate.pem", cert.download)

#Register new device
#TODO: Check when maximum device limitation reached.
Spaceship::Portal.device.create!(name: "iDevice", udid: iDevice)

#Check if nl.iInject.* is already registered
app = Spaceship::Portal.app.find("nl.iInject.*")

if (app.nil?)
	# Create a new app
	Spaceship::Portal.app.create!(bundle_id: "nl.iInject.*", name: "iInject")
end


# Create a new provisioning profile with all devices (by default)
profile = Spaceship::Portal.provisioning_profile.development.create!(bundle_id: "nl.iInject.*", certificate: cert, name: "new#{Time.now.to_i}")

newProfile = Spaceship::Portal.provisioning_profile.all.first

if !(newProfile.valid?)
	print "There was a problem with the provisioning generation\n"
	exit(1)
elsif !(newProfile.certificate_valid?)
	print "There was a problem with the provisioning generation\n"
	exit(1)
end 

# Store the new profile on the filesystem
if (File.exists? "#{Dir.home}/.isign/isign.mobileprovision")
	print "Removing exisitng mobileprovision file\n"
	File.delete("#{Dir.home}/.isign/isign.mobileprovision")
end 

print "Writing new mobileprovision file\n"
File.write("#{Dir.home}/.isign/isign.mobileprovision", newProfile.download)
