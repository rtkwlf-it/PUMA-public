#!/bin/bash


# this edits a plist on the users machine with the information from an autopkg recipe
# this should live in the autopkg override folder or a shared folder that is seached by autopkg

appName="%NAMEFORUPDATER%" # These get replaced by recipe execution
appVersion="%version%" # These get replaced by recipe execution
appPolicyTrigger="%POLICY_EVENT_TRIGGER%" # This gets replace by recipe execution
appBuildDateTime="%datetime%" # This gets replace by recipe execution (UTC)
appTimeStamp=$(date -juf "%Y-%m-%d %H:%M:%S" "$appBuildDateTime" +%s 2>/dev/null)    # This gets filled out when ran on the end users device
appPath="%APPPATH%" # This gets replace by recipe execution
appSilentMode="%SILENT_MODE%" # Integer 0-3 if the application being patched supports updating in the background
    ### 0 = disabled do not update in silent mode
    ### 1 = enabled update in silent mode
    ### 3 = force update in silent mode 
    ### 4 = force update in silent mode and Do not notify

mkdir -p "/Library/Application Support/PlistPatcher" # create the endpoint path
plistPath="/Library/Application Support/PlistPatcher/updatesAvailable.plist" # location for updates to be stored in pairs with version and app name


# built as function so could be incorporated into larger script in the future if needed
CheckForUpdatesFile() {

    if [[ -f $plistPath ]]; then # Check if the plist file exists
        # Check if the App dictionary exists
        appNamePlist=$(plutil -type $appName $plistPath)
        if [[ $appNamePlist = "dictionary" ]]; then # if the App dictionary exists
            # update other values
            plutil -replace "$appName".Version -string "${appVersion}" "${plistPath}"   # Creates Dictionary entry of the version number with a key of Version
            plutil -replace "$appName".TimeStamp -integer "${appTimeStamp}" "${plistPath}"  # Creates Dictionary entry of the timestamp this was added to the file with a key of TimeStamp
            plutil -replace "$appName".AppPath -string "${appPath}" "${plistPath}"  # Creates Dictionary entry of the AppPath where PP can look for version comparision with a key of AppPath
            plutil -replace "$appName".Critical -bool false "${plistPath}"  # Creates Dicroionary entry to check if the patch is a critical patch
            plutil -replace "$appName".PolicyTrigger -string "${appPolicyTrigger}" "${plistPath}"   # Creates Dicroionary entry of the event trigger for the Jamf install policy
            plutil -replace "$appName".SilentMode -integer "${appSilentMode}" "${plistPath}"    # Creates Dictionary entry of integer 0-3 if the application supports updating in the background
        else # Else
            # Add App dictionary and everything else
            plutil -replace "$appName" -xml '<dict/>' "${plistPath}"    # Creates Plist Dictionary with key label of the app name
            plutil -replace "$appName".Version -string "${appVersion}" "${plistPath}"   # Creates Dictionary entry of the version number with a key of Version
            plutil -replace "$appName".TimeStamp -integer "${appTimeStamp}" "${plistPath}"  # Creates Dictionary entry of the timestamp this was added to the file with a key of TimeStamp
            plutil -replace "$appName".AppPath -string "${appPath}" "${plistPath}"  # Creates Dictionary entry of the AppPath where PP can look for version comparision with a key of AppPath
            plutil -replace "$appName".Critical -bool false "${plistPath}"  # Creates Dicroionary entry to check if the patch is a critical patch
            plutil -replace "$appName".PolicyTrigger -string "${appPolicyTrigger}" "${plistPath}"   # Creates Dicroionary entry of the event trigger for the Jamf install policy
            plutil -replace "$appName".SilentMode -integer "${appSilentMode}" "${plistPath}"    # Creates Dictionary entry of integer 0-3 if the application supports updating in the background
        fi
    else
        # Create it with current default values
        plutil -create xml1 "${plistPath}"  # Creates the xml plist file, do NOT want a binary file
        plutil -replace "$appName" -xml '<dict/>' "${plistPath}"    # Creates Plist Dictionary with key label of the app name
        plutil -replace "$appName".Version -string "${appVersion}" "${plistPath}"   # Creates Dictionary entry of the version number with a key of Version
        plutil -replace "$appName".TimeStamp -integer "${appTimeStamp}" "${plistPath}"  # Creates Dictionary entry of the timestamp this was added to the file with a key of TimeStamp
        plutil -replace "$appName".AppPath -string "${appPath}" "${plistPath}"  # Creates Dictionary entry of the AppPath where PP can look for version comparision with a key of AppPath
        plutil -replace "$appName".Critical -bool false "${plistPath}"  # Creates Dicroionary entry to check if the patch is a critical patch
        plutil -replace "$appName".PolicyTrigger -string "${appPolicyTrigger}" "${plistPath}"   # Creates Dicroionary entry of the event trigger for the Jamf install policy
        plutil -replace "$appName".SilentMode -integer "${appSilentMode}" "${plistPath}"    # Creates Dictionary entry of integer 0-3 if the application supports updating in the background
    fi
}

# Check if the 'appName' is empty or has the default value of NAMEFORUPDATER
if [[ -z "$appName" || "$appName" == *"NAMEFORUPDATER"* ]]; then
    echo "Name for updater unavailable EXIT"
    exit 1 
fi

CheckForUpdatesFile # run the function



