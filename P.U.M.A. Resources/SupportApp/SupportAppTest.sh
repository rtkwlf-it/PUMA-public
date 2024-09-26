#!/bin/bash

# shellcheck disable=all
## This is a very basic script designed to be modified for specific use cases
## This script can be setup to run every time the support app menu is opened, 
## and it will populate the menu extenstion attribute for App Updates Available

# Support App preference plist
preference_file_location="/Library/Preferences/nl.root3.support.plist"

# PUMA Plist
DEBUG=1 #set to not 0 enables extra output in logs
plistPath="/Library/Application Support/PlistPatcher/updatesAvailable.plist"
patchDelay=7200
patchEnforcement=172800 # 48hrs as seconds
currentTime=$(date +%s)
pilotUserFile="/Library/Application Support/PlistPatcher/pilot"
logLocation="/Library/Application Support/PlistPatcher/plistpatcher.log"
IFS=$' \t\n\0' ## Reset IFS to default

logIt() {
  echo -e "$(date -ju +"%a %b %d %T") $(hostname -s) $(basename "$0")[$$]: $*" | tee -a "$logLocation"
}

gotApps() {
    # Function
    ## Checks the plist for dictionarys labeled with app names
    if [[ $DEBUG != 0 ]]; then
        logIt "######## DEBUG ENABLED ########"
    fi
    OLDIFS=$IFS  # get old IFS so it can be set back to it
    IFS=$'\n'   # set separator to newlines
    updatesPlist=( $(xmllint -xpath "/plist/dict/key/text()" $plistPath) ) # add each key from plist as an item in the array
    numberofPlistItems="${#updatesPlist[@]}" # get number of apps in the plist via this array
    IFS=$OLDIFS # set IFS back to its original setting
    i=0 # Keep track of how many time ran through the whole loop 
    # LOOP
    # Get the dictionary data for each application (version, apppath, timestamp)
    while [ $i -lt $numberofPlistItems ]; do

    #   # Get Data out of the Plist containing update information
        applicationPlistVersion[$i]+=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:Version" "$plistPath") # get each app version key into an array for comparision
        applicationPlistAppPath[$i]+=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:AppPath" "$plistPath") # get each Application Path into an array for ease of use 
        applicationPlistTimeStamp[$i]+=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:TimeStamp" "$plistPath") # get each timestamp into an array for ease of use
        applicationPlistCritical[$i]+=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:Critical" "$plistPath") # get each Critical status into an array for ease of use
        applicationPlistPolicyTrigger[$i]+=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:PolicyTrigger" "$plistPath") # get each Policy trigger for debugs sake, this is used as a different variable later on in the process
        applicationSilentMode[$i]+=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:SilentMode" "$plistPath" 2>/dev/null) # get the integer value if silent mode is enabled on the application entry
        re='[0-4]'
        if ! [[ "{applicationSilentMode[$i]}" =~ $re ]]; then
            applicationSilentMode[$i]=0
            logIt ""
            logIt "WARN ######## SilentMode KVP NULL, disabling ${updatesPlist[$i]} SilentMode this run"
        fi
        IFS=$'\n' # change IFS to new line
        # Moving the displayname fillout to an earlier loop so it can be used elsewhere in the script.
        applicationDisplayName[$i]+=$(basename $(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:AppPath" "$plistPath") | sed 's/.app//g') # grab the application basename without the .app for list display
        IFS=$' \t\n\0' #change back to default
        # Detection for if app is running
        isItRunning[i]+=$(pgrep "${updatesPlist[$i]}" | awk 'END{print NF}') # will return 0 if there are no processes by the name of the application running
        # Use the AppPath to check if the user has the application before we start trying to grab the installed version
        if [[ -d "${applicationPlistAppPath[$i]}" ]]; then
            # This next line checks whats on the users computer based on the AppPath String in the array above
            #logIt "Found ${updatesPlist[$i]} at ${applicationPlistAppPath[$i]}"
            applicationInstalledVersion[$i]+=$(plutil -extract "CFBundleShortVersionString" raw -o - "${applicationPlistAppPath[$i]}"/Contents/Info.plist) # get the LOCAL installed version for later comparision
        else
            logIt "${updatesPlist[$i]} NOT found at ${applicationPlistAppPath[$i]} Skipping"
        fi
            if [[ $DEBUG != 0 ]]; then
                logIt ""
                logIt "######## Application: ${updatesPlist[$i]}"
                logIt "App List Display Name: ${applicationDisplayName[$i]}"
                logIt "Found ${updatesPlist[$i]} at ${applicationPlistAppPath[$i]}"
                logIt "Version: ${applicationPlistVersion[$i]}"
                logIt "AppPath: ${applicationPlistAppPath[$i]}"
                logIt "TimeStamp: ${applicationPlistTimeStamp[$i]}"
                logIt "Critical: ${applicationPlistCritical[$i]}"
                logIt "PolicyTrigger: ${applicationPlistPolicyTrigger[$i]}"
                logIt "Installed app version: ${applicationInstalledVersion[$i]}"
                logIt "Application Support Silent Mode: ${applicationSilentMode[$i]}"
                logIt "Application Running greater than zero: ${isItRunning[$i]}"
            fi
        # check to make sure the app exists / there is no bad values before comparing versions and adding to lists
        if [[ "${applicationPlistVersion[$i]}" != *"No such file or directory"* && "${applicationInstalledVersion[$i]}" != *"No such file or directory"* && ! -z "${applicationInstalledVersion[$i]}" ]]; then
            # compare installed version vs plist updater version in a list
            if [[ "$(printf '%s\n' "${applicationPlistVersion[$i]}" "${applicationInstalledVersion[$i]}" | sort -V | head -n1)" = "${applicationPlistVersion[$i]}" ]]; then # Use printf to print the two versions on separate lines, then use sort to sort the highest one to the top
                logIt "Installed version ${applicationInstalledVersion[$i]} is greater than or equal to the plist version ${applicationPlistVersion[$i]}" # Log that the installed version is greater or equal to the plist version
            else
                logIt "Installed version ${applicationInstalledVersion[$i]} is less than ${applicationPlistVersion[$i]}" # Log that the installed version needs to be patch
                plistTimeDifference[$i]+=$(( currentTime - ${applicationPlistTimeStamp[$i]} )) # Calculate the time since the patch was updated in the plist file
                logIt "TimeStamp Difference ${plistTimeDifference[$i]}" # log the difference from when the PU for specific app was updated vs current time
                if [[ "${plistTimeDifference[$i]}" -gt $patchEnforcement || -f $pilotUserFile || "${applicationPlistCritical[$i]}" = "true" ]]; then # Check for critical update, pilot user, or past the 48hrs
                    # If the specified app time difference is past patch enforcement (48hrs)
                    # If the user has the pilot users group file on their computer
                    # If the App has Critical set to True
                    logIt "Add the application(s) to the critical update list"
                    appsNeedingCriticalUpdates[$i]+="${updatesPlist[$i]}" # add the apps that need critical(force installed) updates to a seprate array
                elif [[ "${plistTimeDifference[$i]}" -gt $patchDelay ]]; then
                    # If the App is past the 2 hour patch delay
                    logIt "Non critical updates"
                    appsNeedingUpdates[$i]+="${updatesPlist[$i]}"
                else
                    logIt "######## No Patch Do Nothing ########"
                fi
            fi
        else
            logIt "${updatesPlist[$i]} NOT found at ${applicationPlistAppPath[$i]} Skipping"
        fi
        i=$(($i+1)) # add 1 for next iteration of this loop
    done

    if [[ $DEBUG != 0 ]]; then
        logIt "######## Silent Mode ########"
        logIt "Standard Update Count: "${#appsNeedingUpdates[@]}""
        logIt "Critical Update Count: "${#appsNeedingCriticalUpdates[@]}"" 
        logIt "Standard Updates: ${appsNeedingUpdates[@]}"
        logIt "Critical Updates: ${appsNeedingCriticalUpdates[@]}"
    fi

}

# Alert disable
defaults write "${preference_file_location}" ExtensionAlertA -bool false

# Start spinning indicator
defaults write "${preference_file_location}" ExtensionLoadingA -bool true

# Replace value with placeholder while loading
defaults write "${preference_file_location}" ExtensionValueA -string "Checking for Updates"

# Check for App Updates
gotApps

# set the support app and notify
if [[ "${#appsNeedingCriticalUpdates[@]}" -gt 0 || "${#appsNeedingUpdates[@]}" -gt 0 ]]; then
    totalUpdates=$(( ${#appsNeedingCriticalUpdates[@]} + ${#appsNeedingUpdates[@]} ))

    # Stop spinning indicator
    defaults write "${preference_file_location}" ExtensionLoadingA -bool false

    # Do we have multiple updates or just one?
    if [[ "${totalUpdates}" -gt 1 ]]; then
        # Replace value with placeholder if there are no updates
        defaults write "${preference_file_location}" ExtensionValueA -string "${totalUpdates} Updates Available"
    else
        # Replace value with placeholder if there are no updates
        defaults write "${preference_file_location}" ExtensionValueA -string "${totalUpdates} Update Available"
    fi

    # Alert the user
    defaults write "${preference_file_location}" ExtensionAlertA -bool true

else
    # Stop spinning indicator
    defaults write "${preference_file_location}" ExtensionLoadingA -bool false

    # Replace value with placeholder if there are no updates
    defaults write "${preference_file_location}" ExtensionValueA -string "No Updates"
fi

## Reset IFS to default
IFS=$' \t\n\0'