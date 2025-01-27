#!/bin/bash
# macOSUpgradeHooks - Restore loginwindow mechanisms
# Supports loginwindow plug-ins such as Jamf Connect Login
# Resets loginwindow prior to macOS updates and upgrades
#
## Allows macOS to complete the "last mile" migration updates
## Allows autologin of the user logged in prior to the update
## Restores loginwindow to previous settings after OS updates are complete
#
# Source: https://github.com/kennyb-222/NoMADLoAD_AppleStagedUpdates/
# Author: Kenny Botelho
# 20210515: Changes to work with JCL and also reinstall Rosetta.

# https://macadmins.slack.com/archives/CH7CGG16Y/p1619529274149000?thread_ts=1619528662.148700&cid=CH7CGG16Y

#LogFile
LogFile="/var/log/update.log"
#Log Function
logger() {
    /bin/echo $(date "+%Y-%m-%d %H:%M:%S ") $1 >>"${LogFile}"

}

# Upgrade Hooks
PreUpgrade() {
#!/bin/bash

# Revert loginwindow to macOS default

/usr/local/bin/authchanger -reset
logger "Changed loginwindow to macOS default in PreUpgrade" 

authchanger=$(authchanger -print)
logger "authchangerconfig: $authchanger"


return 0
}

PostUpgrade() {
#!/bin/bash
## Restore loginwindow to jamfconnect

/usr/local/bin/authchanger -reset -jamfconnect
logger "Changed loginwindow to jamfconnect in PostUpgrade" 

authchanger=$(authchanger -print)
logger "authchangerconfig: $authchanger"

return 0
}

MigrationComplete() {
#!/bin/bash
## migrationcomplete
# add your commands here or call script(s)

#Reinstall Rosetta after Update
 processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Apple")
  if [[ -n "$processor" ]]; then
    rosetta=$(/usr/sbin/softwareupdate --install-rosetta --agree-to-license)
    logger "Rosetta reinstall: $rosetta"
  else
      logger "Intel nothing to do reinstall"

  fi

return 0
}

#####################################
#   DO NOT MODIFY BELOW THIS LINE   #
#####################################

    logger "---------------------------------------------------------" >> /var/log/update.log
    logger "Start Upgrade Hocks" 
Install() {
    # Copy script to destination path
    cp "$0" ${ScriptPath}
    
    # Create LaunchDaemon to watch for "Stagged Apple Upgrades"
    cat > ${PlistPath} << \EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.AppleUpgrade.Hooks</string>
    <key>LaunchOnlyOnce</key>
    <true/>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>/private/var/db/.AppleUpgradeHooks.sh</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>WatchPaths</key>
    <array>
        <string>/private/var/db/.StagedAppleUpgrade</string>
        <string>/private/var/db/.AppleUpgrade</string>
    </array>
</dict>
</plist>
EOF

    # Set Permissions
    chmod 755 ${PlistPath} ${ScriptPath}
    
    # Load LaunchDaemon
    /bin/launchctl load ${PlistPath}
    logger "Installed Upgrade Hocks" 

}

FetchUpgradeInfo() {
    # Fetch staged upgrade information
    UpgradeVersion=$(/usr/libexec/PlistBuddy -c \
                "Print :0:auxinfo:macOSProductVersion" \
                ${ProductMetadataPath} )
    UpgradeBuild=$(/usr/libexec/PlistBuddy -c \
                "Print :0:auxinfo:macOSProductBuildVersion" \
                ${ProductMetadataPath} )
    UpgradeProductKey=$(/usr/libexec/PlistBuddy -c \
                "Print :0:cachedProductKey" \
                ${ProductMetadataPath} )
    UpgradeUser=$(/usr/libexec/PlistBuddy -c \
                "Print :User" /private/var/db/.StagedAppleUpgrade )
    UpgradeType=$(/usr/libexec/PlistBuddy -c \
                "Print :UpgradeType" /private/var/db/.StagedAppleUpgrade )
    # Set upgrade type flag            
    if [[ ${UpgradeType} == "Upgrade" ]]; then
        MajorUpgrade=1
    fi
}

Uninstall() {
    # Uninstall launchd task and script
    echo "removing AppleUpgradeHooks..."
    rm ${ScriptPath} ${PlistPath}
    /bin/launchctl remove com.AppleUpgrade.Hooks
    logger "Uninstalled Upgrade Hocks" 

}

# Set environment
export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
ScriptPath="/private/var/db/.AppleUpgradeHooks.sh"
PlistPath="/Library/LaunchDaemons/com.AppleUpgrade.Hooks.plist"
ProductMetadataPath="/System/Volumes/Data/Library/Updates/ProductMetadata.plist"
launchdPID=$(launchctl list | grep com.AppleUpgrade.Hooks | awk '{print $1}')

# Check if root
if [[ "$(id -u)" != 0 ]]; then
    echo "This script must be run as root. Exiting..."
    exit 1
fi

# Check if we need to install or uninstall
if [[ $1 == "uninstall" || $4 == "uninstall" ]]; then
    Uninstall
    exit $?
elif [[ -z ${launchdPID} ]]; then
    Install
    exit $?
fi

# Check which stage of the upgrade we are in
if [[ -f /private/var/db/.StagedAppleUpgrade ]] &&
   [[ ! -f /private/var/db/.AppleUpgrade ]]; then
    # Perform pre-upgrade actions
    FetchUpgradeInfo
    PreUpgrade
elif [[ -n ${UpgradeVersion} ]]; then
    exit 1
elif [[ ! -f /private/var/db/.StagedAppleUpgrade ]] &&
     [[ ! -f /private/var/db/.AppleUpgrade ]] &&
     [[ -z ${UpgradeVersion} ]]; then
    # Perform post-upgrade actions
    PostUpgrade
    # Wait for login
    while ! /usr/bin/pgrep -x "Dock" > /dev/null; do
        sleep 10
    done
    # Wait for the post upgrade login to complete
    while /usr/bin/pgrep -x "Installer Progress" > /dev/null; do
        sleep 10
    done
    # Perform post-upgrade-login actions
    MigrationComplete
fi
    logger "End Upgrade Hocks" 
    logger "---------------------------------------------------------" 

exit 0
