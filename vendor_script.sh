#!/bin/bash
#!/bin/sh
#This script uses the https://github.com/vuid-com/mdmvendorsign project to perform some of the vendors siging tasks.
RED='\033[0;31m'
NC='\033[0m'
BLUE='\033[34m'
function step1 {
	echo -e "\n\nStarting step 1..."
	echo -e "In this step, we are generating the vendors/siging authority mdm private key and csr(certificate signing request).
	We will need to send this csr to Apple to get it signed. When we get a certificate from Apple, it gives us the ability/authority to generate APNS_MDM certificates.
	This will expire in one year from today as mandated by Apple and must be rekewed next year.
	To proceed, first enter a password to be used for the private key of the mdm vendors/siging authority private key.
	\033[31m Note that you will need to remember the password for future reference. \033[0m"
	echo -e "Enter the vendor private key password(minimum password length - 5 charactors):"
	read -s vendorPrivateKeyPassword;
	# Clearing old files
	rm -f vendorPrivateKey.txt
	rm -f vendorPrivateKey.pem
	rm -f vendor.csr
	# Writing the password to a temparary file, to maintain the password between steps and to handle if the user restarts the script.
	echo $vendorPrivateKeyPassword > vendorPrivateKey.txt
	# Creating a private key and csr for vendor. 
	openssl genrsa -des3 -passout file:vendorPrivateKey.txt -out vendorPrivateKey.pem 2048
	openssl req -new -passin file:vendorPrivateKey.txt -key vendorPrivateKey.pem -out vendor.csr
	rm -rf output
	rm -rf inputs
	mkdir output
	mkdir inputs
	echo -e "${RED}***************Important*****************${NC}"
	echo -e "First step is complete!! Now you need to go to https://developer.apple.com/account/ios/certificate/ and upload the vendor.csr by 
	following the instructions in documentation DOC LINK HERE."
	echo -e "${RED}After you have the mdm.csr file from Apple, copy it to inputs folder to proceed."
	step2
}

function step2 {
	echo "Starting step 2"
	echo -e "${RED}***************Important*****************"
	echo -e "Make sure you have copied the mdm.cer file you downloaded to the folder inputs folder${NC}"
	while [ ! -f ./inputs/mdm.cer ]
	do
	  sleep 1
	done
	echo -e "mdm.cer File is available!"
	rm -f mdm.pem
	rm -f customerPrivateKey.txt
	rm -f customerPrivateKey.pem
	rm -f customer.csr
	rm -f plist_encoded
	vendorPrivateKey=`cat vendorPrivateKey.txt`
	openssl x509 -inform der -in ./inputs/mdm.cer -out mdm.pem
	openssl pkcs12 -export -passout pass:$vendorPrivateKey -out vendor.p12 -passin pass:$vendorPrivateKey  -inkey vendorPrivateKey.pem -in mdm.pem 
	openssl pkcs12 -passin pass:$vendorPrivateKey -in vendor.p12 -nocerts -passout pass:$vendorPrivateKey  -out vendorKey.pem
	openssl rsa -passin pass:$vendorPrivateKey -in vendorKey.pem -out noPasswordVendorPrivate.key
	
	echo -e "\n\n Next, it is necessery to create a customer csr and a private key which we will be signed with the vendors/siging authority certificate Apple issued. "
	echo -e "Enter a password for customer private key(minimum password length - 5 charactors): Note that you will need to remember the password for future reference. "
	read -s customerPrivateKeyPassword;
	echo $customerPrivateKeyPassword > customerPrivateKey.txt
	openssl genrsa -des3 -passout file:customerPrivateKey.txt -out customerPrivateKey.pem 2048
	openssl req -new -passin file:customerPrivateKey.txt -key customerPrivateKey.pem -out customer.csr
	python ./mdmvendorsign-master/mdm_vendor_sign.py --csr ./customer.csr --key ./noPasswordVendorPrivate.key --mdm ./inputs/mdm.cer
	echo "Siging the certificate is complete."
	echo "Next, upload the plist_encoded file in the mdmvendorsign-master folder to apple portal and download MDM_Certificate.pem and copy it to the inputs folder. 
	File name will be diffrent based on your organisation name, hence, please rename the file to MDM_Certificate.pem. Please note that if you are reknewing the certificates, do not create a new certificate and instread reknew."
	echo -e "${RED}After you have the MDM_Certificate.pem file from Apple, rerun the script and jump to step 3${NC}"
	step3
}

function step3 {
	echo "Starting step 3."
	echo "Waiting for MDM_Certificate.pem to be copied to the inkeyputs folder."
	while [ ! -f ./inputs/MDM_Certificate.pem ]
	do
	  sleep 1
	done
	echo -e "MDM_Certificate.pem File is available!"
	rm -f customerKeyNoPass.pem
	rm -f MDM_APNSCert.pem
	rm -f MDM_APNSCert.pfx
	rm -f ./output/MDM_APNSCert.pfx
	openssl rsa -passin file:customerPrivateKey.txt -in customerPrivateKey.pem -out customerKeyNoPass.pem
	cp MDM_Certificate.pem MDM_APNSCert_tmp.pem
	echo -e "" >> MDM_APNSCert_tmp.pem 
	cat MDM_APNSCert_tmp.pem customerKeyNoPass.pem > MDM_APNSCert.pem
	rm MDM_APNSCert_tmp.pem
	openssl pkcs12 -export -passout file:customerPrivateKey.txt -out MDM_APNSCert.pfx -inkey customerKeyNoPass.pem -in MDM_APNSCert.pem
	cp MDM_APNSCert.pfx ./output

	echo "All Done!!!!"
	echo "Summery"
	echo "Find the MDM_APNSCert.pfx inside the output folder."
	openssl x509 -in ./inputs/MDM_Certificate.pem -text >> tmp.txt
	python fetchUUID.py
	rm tmp.txt
	echo "Password of the MDM_APNSCert.pfx is the password you used for customer private key. This can be found inside customerPrivateKey.txt"
	echo -e "\nAll Done!!!! It is highly advised to delete the passwords stored in file and some temparary files. Do you want to perform this now? Y/N"
	read val5;
	if [ $val5 == "Y" ]
	then
		rm -f vendorPrivateKey.txt
		rm -f noPasswordVendorPrivate.key
		rm -f customerPrivateKey.txt
		echo "Temparary files cleared!!! Please keep the content of this folder secure."
	fi
}


echo -e "\n\n\n\n\n\n\n\n\n\n${BLUE}Welcome to MDM certificate generation siging process ${NC} \n\n\n"
echo -e "${RED}***************Important*****************"
echo -e "Please read the steps and instruction carefully and follow along. ${NC} "
echo "There are 3 steps in this process, you will need to complete in order to obtain the MDM APNS certificate."
echo "Please complete the pre-requisits section of the blog prior to starting any step. At any point, if you need to restart a step, exit the srcipt(control + c) and restart with steps flag(sh vendor_script.sh <step number 1,2,3>), eg:- sh vendor_script.sh 1"
step=$1;
if [ -z "$1" ]
then
	echo -e "Which step do you want to run? If this is the first time you are running, type 1."
	read step
fi
if [ $step -eq "1" ]
then
	step1
elif [ $step -eq "2" ]
then
	step2
elif [ $step -eq "3" ]
then
	step3
else
	echo -e "\n\n\nNot a valid step"
fi





