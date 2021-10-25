#!/usr/bin/env sh

### configuration section
OWNER=just-another-muensterhack
REPO=revent
NAME=release-apk

ORG_NAME=de.reventapp.app

USER=felbinger
TOKEN=XXXXXXXX_GH_TOKEN_XXXXXXXX
### end of configuration section

# install dependencies
if ! which jq >/dev/null || ! which adb >/dev/null; then
  echo "Installing jq and adb..."
  sudo apt install -y jq android-tools
fi

echo "Getting artifacts..."

# get artifact url
url=$(curl --silent --user $USER:$TOKEN "https://api.github.com/repos/${OWNER}/${REPO}/actions/artifacts" \
 | jq -r " [.artifacts[] | select(.name == \"${NAME}\") | .archive_download_url][0]")

# download artifact
curl --location --silent --output artifact.zip --user $USER:$TOKEN $url
unzip -q -d artifact artifact.zip
rm artifact.zip

# if multiple devices connected
if [ $(adb devices -l | grep . | sed 1d | wc -l) -gt 1 ]; then
  specify_id=1
  adb devices -l | grep . | sed 1d
  read -p "Multiple devices detected, give me a id (enter for all): " device_id
fi

if [ -z $device_id ]; then
  script_done=1
  for id in $(adb devices -l | grep . | sed 1d | cut -d " " -f1); do
    echo "Deploying to device: $(adb devices -l | grep $id)"

    echo -n "Uninstalling ${ORG_NAME}: "
    adb -s $id uninstall ${ORG_NAME}

    echo -n "Installing $(echo artifact/*.apk): "
    adb -s $id install artifact/build/app/outputs/apk/release/*.apk
  done
fi

if [ ${script_done} -eq 0 ]; then
  if [ ${specify_id} -eq 1 ]; then
    adb -s $device_id devices | grep unauthorized
  else
    adb devices | grep unauthorized
  fi

  # check if device is ready for apk installation
  if [ $? -eq 0 ]; then
    echo "Unable to access device: Unauthorized! Check device screen!"
    exit 1
  fi

  echo -n "Uninstalling ${ORG_NAME}: "
  # uninstall app
  if [ ${specify_id} -eq 1 ]; then
    adb -s $device_id uninstall ${ORG_NAME}
  else
    adb uninstall ${ORG_NAME}
  fi

  echo -n "Installing $(echo artifact/*.apk): "
  # install apk on device
  if [ ${specify_id} -eq 1 ]; then
    adb -s $device_id install artifact/build/app/outputs/apk/release/*.apk
  else
    adb install artifact/build/app/outputs/apk/release/*.apk
  fi
fi
