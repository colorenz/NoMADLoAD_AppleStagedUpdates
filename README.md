# JamConnt Login AD - AppleStagedUpdates Workaround

Currently JamfConnect Login does not support the supression of it's loginwindow plugin during the macOS update/upgrade process, which prevents the completion of user-level macOS updates. This will result in forcing the user through a second update process following user login after the inital update. The only method to workaround this is to disable JamfConnect Login AD entirely prior to updating or upgrading the OS.

This script will automatically engage when macOS updates or upgrades are staged on the device, allowing macOS to complete the entire "AppleUpgrade" process.

### Update: Now supports Jamf Connect Login

### What does it do?
- Disables JamfConnect Login only during staged macOS updates and upgrades requiring reboot
- Allows macOS to complete the "last mile" user-level updates
- Allows autologin of the user logged in previously before the update
- Prevents macOS from resetting the loginwindow back to default settings across upgrades/updates (Preserves JamfConnect Login)
- Restores JamfConnect Loging Windows settings after the OS update is complete 
- Adds a Reboot to fix Defender Network Extension


### How to install

`sudo /bin/bash /path/to/JamfConnectLogin_UpgradeHook.sh`

### How to uninstall

`sudo /bin/bash /private/var/db/.AppleUpgradeHooks.sh "uninstall"`

##### Notes
Tested on (11.2 - 12.5.x) macOS release updates

This was created from the "macOSUpgradeHooks" project
https://github.com/kennyb-222/macOSUpgradeHooks
