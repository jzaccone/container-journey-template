#!/bin/bash
#
# Automatically install the bluemix cli
set -e

if [[ -z "$FORCE" ]]; then
    # we are not in a force scenario
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
    else
        echo "No /etc/os-release found, this might not work on your version of Linux"
        echo "Rerun with FORCE=1 to bypass"
        exit 1
    fi
    if [[ "$NAME" =~ "Ubuntu" ]]; then
        echo "Found compatible version of Linux"
    else
        echo "'$NAME' is not yet supported in this script"
        exit 1
    fi
fi

# Work in a temporary space which makes cleanup much easier
#
TEMPDIR=$(mktemp -d)
pushd $TEMPDIR

if [[ -z "$BXUSER" ]]; then
    read -p "Enter your bluemix userid and press [ENTER]: " BXUSER
fi
if [[ -z "$BXPASS" ]]; then
    read -p "Enter your bluemix password and press [ENTER]: " BXPASS
fi

# Step 1: download and install bluemix, verifying integrity
echo "Installing bluemix client"
BLUEMIX_TAR=Bluemix_CLI_0.5.2_amd64.tar.gz
curl -o $BLUEMIX_TAR "https://public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/$BLUEMIX_TAR"
# note, if the bluemix tar is updated, this sha256 also needs to be
echo "9cefae48cb3f5f3765abd704c21920f5678df93c09b792554819ddf4042af228  $BLUEMIX_TAR" > bluemix.sha
# this will error ending the script if there is an issue
sha256sum -c bluemix.sha --strict
tar zxvf $BLUEMIX_TAR
sudo ./Bluemix_CLI/install_bluemix_cli

# Step 2: sign into bluemix
echo "Configuring bluemix client"
# if a BXACCOUNT was specified, select that account without having to
# go interactive. It would be nice if bx login didn't prompt you for this.
if [[ -z "$BXACCOUNT" ]]; then
    bx login -a https://api.ng.bluemix.net -u $BXUSER -p $BXPASS
else
    echo "$BXACCOUNT" | bx login -a https://api.ng.bluemix.net -u $BXUSER -p $BXPASS
fi
if [[ -z "$(bx plugin repos | grep Bluemix)" ]]; then
    bx plugin repo-add Bluemix https://plugins.ng.bluemix.net
fi
bx plugin install container-service -r Bluemix
bx cs init

# Step 3: get kubectl
#
# TODO: would be good to verify integrity of binary
echo "Install kubernetes control"
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
sudo install kubectl /usr/local/bin


# Step Z: cleanup
echo "Cleaning up"
popd
rm -rf $TEMPDIR

echo "Success!"
