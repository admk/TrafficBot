#! /bin/sh
#
# This uninstalls everything installed by the sample.  It's useful 
# when testing to ensure that you start from scratch.

sudo launchctl unload -w /Library/LaunchDaemons/com.akkloca.TrafficBotHelper.plist
sudo rm /Library/LaunchDaemons/com.akkloca.TrafficBotHelper.plist
sudo rm /Library/PrivilegedHelperTools/com.akkloca.TrafficBotHelper
