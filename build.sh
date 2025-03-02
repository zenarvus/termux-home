#!/bin/bash

# ----------- CONFIGURATION ----------- #
PROJECT_STRUCTURE="com/zenarvus/termuxhome"
MIN_SDK_VERSION=16
# ----------- CONFIGURATION ----------- #

#if no KS_PASSWORD argument is given, use "password"
if [[ ! -n "$(echo $KS_PASSWORD)" ]]; then
	echo "No password is given for the key store. Using the default one."
	KS_PASSWORD="password"
fi

# Code to stop the script on error.
function catch_error() {
  local error_code="$?"
  echo -e "\e[31mError:\e[0m $error_code"
}
trap catch_error ERR; set -e

BUILD_DIR=$PWD
PROJECT_DIR=$BUILD_DIR/app

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Directory does not exist"; exit 1;

else echo "Directory exists, continuing..."; fi

# Clean up junk from last build:
rm -rf $BUILD_DIR/build
mkdir $BUILD_DIR/build
mkdir $BUILD_DIR/build/dex
mkdir $BUILD_DIR/build/classes

# Begin compilation!
echo -e "\e[33mRunning aapt2...\e[0m"
aapt2 compile -v --dir $PROJECT_DIR/res -o $BUILD_DIR/build/resources.zip

# -I gives the path to the android platform’s android.jar,
# --manifest specifies the android manifest,
# --java specifies the path to generate the R.java file.
# --o specifies the output path.

aapt2 link -v \
  -I $BUILD_DIR/tools/android.jar \
  --manifest $PROJECT_DIR/AndroidManifest.xml \
  --java $BUILD_DIR/build/ \
  -o $BUILD_DIR/build/link.apk \
   $BUILD_DIR/build/resources.zip \
   --auto-add-overlay

# This will compile our code to java bytecode
# and place the .class files in build/classes
# directory. Take note of the R.java file which
# is the one that was generated in the previous step.
# Without --release=9 nothing will work

JAVA_FILE_LIST=$(find $PROJECT_DIR/java -type f -name \*.java)
echo -e "\e[33mRunning $(javac --version)...\e[0m"
javac --release=9 -verbose -d $BUILD_DIR/build/classes --class-path \
	$BUILD_DIR/tools/android.jar \
	$JAVA_FILE_LIST $BUILD_DIR/build/$PROJECT_STRUCTURE/R.java

# Once we have java bytecode we now convert it to
# DEX bytecode that runs on android devices.
# This is done using android’s d8 commandline tool.

# IF you dont include that 'cd' below, the fails will be monumental.
#
# dx WILL NOT FUNCTION unless the directory structure
# matches the package name, ie com/helloworld com.helloworld.
# if it even catches a glimpse that its actually src/com/helloworld
# it will uncompromisingly refuse to communicate or function

# To convert into dex :
#echo "\e[33mRunning ds...\e[0m"
#cd $BUILD_DIR/build/classes
#dx --dex --verbose --debug --min-sdk-version=$MIN_SDK_VERSION \
#	--output=classes.dex $PROJECT_STRUCTURE/*.class \
echo -e "\e[33mRunning d8...\e[0m"
cd $BUILD_DIR/build/dex
d8 --debug --classpath $BUILD_DIR/tools/android.jar \
       --output ./ \
       $(ls -1 $BUILD_DIR/build/classes/$PROJECT_STRUCTURE |\
        xargs -I{} printf "%s "\
        "$BUILD_DIR/build/classes/$PROJECT_STRUCTURE/{}")

# The output will be a file called classes.dex.
# We then need to add this file into our link.apk
# that was generated in the linking stage:

echo -e "\e[33mRunning zip...\e[0m"
zip -v -u $BUILD_DIR/build/link.apk classes.dex

# Next we need to zip align our apk using the
# zipalign tool and then sign the apk using the
# apksigner tool.

echo -e "\e[33mRunning zipalign...\e[0m"
zipalign -v -f -p 4 $BUILD_DIR/build/link.apk $BUILD_DIR/build/zipout.apk

# (To sign the application you will need to have a
# public-private key pair. You can generate one
# using java’s keytool. This you only do once, so
# if its your first time thru, uncomment the 'keytool'
# line and answer the questions:
if [[ ! -e "$PROJECT_DIR/key.keystore" ]]; then
	echo -e "\e[33mRunning keytool...\e[0m"
	keytool -genkeypair -keystore $PROJECT_DIR/key.keystore -keyalg RSA -storepass $KS_PASSWORD
fi

#KEYSTORE_DIR=".keystore"
#KEY_PK8=${KEYSTORE_DIR}/key.pk8
#X509_PEM=${KEYSTORE_DIR}/cert.x509.pem
#REQ_PEM=${KEYSTORE_DIR}/req.pem
#KEY_PEM=${KEYSTORE_DIR}/key.pem
#if [ ! -f "$X509_PEM" ] ; then
#	openssl genrsa -out $KEY_PEM 2048
#	openssl req -new -key $KEY_PEM -out $REQ_PEM
#	openssl x509 -req -days 10000 -in $REQ_PEM \
#	-signkey $KEY_PEM -out $X509_PEM
#	openssl pkcs8 -topk8 -outform DER -in $KEY_PEM \
#	-inform PEM -out $KEY_PK8 -nocrypt
#fi

# And sign!
echo -e "\e[33mRunning apksigner...\e[0m"
apksigner sign \
  --verbose \
  --ks $PROJECT_DIR/key.keystore \
  --ks-pass pass:$KS_PASSWORD \
  --out $BUILD_DIR/output.apk $BUILD_DIR/build/zipout.apk

#apksigner sign \
#  -in $BUILD_DIR/build/zipout.apk \
#  -out $BUILD_DIR/output.apk \
#  -key ../${KEY_PK8} \
#  -cert ../${X509_PEM}

# The output of this command is an apk final.apk.
echo
echo -e "\e[33mThe apk is saved to $BUILD_DIR/output.apk\e[0m"

# Remove junk
rm -rf $BUILD_DIR/build
