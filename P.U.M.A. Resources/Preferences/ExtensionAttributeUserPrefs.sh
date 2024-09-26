#!/bin/bash

# Default will return string value "Enabled" for an EA labeled as User Preferences
# Uncommenting Line 12 will list the modified keys from the user

# Location of the user preferences plist
userPrefsPath="/Library/Preferences/com.aw.endpoint.puma.plist"

# Basic EA response
if [[ -f "${userPrefsPath}" ]]; then 
    echo "<result>Enabled</result>"
    #echo "<result>User Modified Settings: $(xmllint -xpath "/plist/dict/key/text()" "${userPrefsPath}" | xargs)</result>"
else
    echo "<result>Disabled</result>"
fi