#!/bin/bash
#
# DigitalOcean, LLC CONFIDENTIAL
# ------------------------------
#
#   2021 - present DigitalOcean, LLC
#   All Rights Reserved.
#
# NOTICE:
#
# All information contained herein is, and remains the property of
# DigitalOcean, LLC and its suppliers, if any.  The intellectual and technical
# concepts contained herein are proprietary to DigitalOcean, LLC and its
# suppliers and may be covered by U.S. and Foreign Patents, patents
# in process, and are protected by trade secret or copyright law.
#
# Dissemination of this information or reproduction of this material
# is strictly forbidden unless prior written permission is obtained
# from DigitalOcean, LLC.


# Creates and uploads the 'fat tarball' for `doctl sandbox install`

# Change these variables on changes to the space we are uploading to or naming conventions within it
TARGET_SPACE=do-serverless-tools
DO_ENDPOINT=nyc3.digitaloceanspaces.com
SPACE_URL="https://$TARGET_SPACE.$DO_ENDPOINT"
TARBALL_NAME=doctl-sandbox.tar.xz

# Change this variable when local setup for s3 CLI access changes
AWS="aws --profile do --endpoint https://$DO_ENDPOINT"

# Define a test flag
if [ "$1" == "--test" ]; then
		TESTING=true
elif [ -n "$1" ]; then
		echo "Illegal argument"
		exit
fi

# Orient
SELFDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SELFDIR

set -e

echo "Removing old artifacts"
rm -rf sandbox *.tar.gz

echo "Ensuring a full install"
npm install

echo "Building the code"
npx tsc

# For testing we symlink the "real" sandbox as viewed by the local doctl
# Otherwise, we make a sandbox folder for staging the upload
if [ -n "$TESTING" ]; then
		echo "Linking the local sandbox for provisioning"
		ln -s "$HOME/Library/Application Support/doctl/sandbox" .
		echo "Removing former node_modules"
		rm -fr sandbox/node_modules
else
		echo "Making sandbox folder for staging"
    mkdir sandbox
fi

echo "Moving artifacts to the sandbox folder"
cp lib/index.js sandbox/sandbox.js
cp -r node_modules sandbox

if [ -n "$TESTING" ]; then
		echo "Test setup complete"
		rm sandbox
		exit
fi

echo "Making the tarball"
tar cJf "$TARBALL_NAME" sandbox

echo "Uploading"
$AWS s3 cp "$TARBALL_NAME" "s3://$TARGET_SPACE/$TARBALL_NAME"
$AWS s3api put-object-acl --bucket "$TARGET_SPACE" --key "$TARBALL_NAME" --acl public-read