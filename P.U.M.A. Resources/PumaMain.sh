#!/bin/bash

# shellcheck disable=SC2207,SC2015,SC2048


## Reset IFS to default
IFS=$' \t\n\0'

###################################################################################Functions###################################################################################

# declare configuration files and variables
preCheck() {

    echo "INFO: Starting Precheck"
    # Generate unique commandfile
    CommandFile="/var/tmp/$(uuidgen | sed 's/-//g').dialog.log" ## To use the command file add following to dialog ## --commandfile "$CommandFile"
    readonly CommandFile

    LoggedInUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }') # Get the user logged into the computer
    readonly LoggedInUser
    
    currentTime=$(date +%s)
    readonly currentTime

    pumaManagedPrefs="/Library/Managed Preferences/com.it.endpoint.puma.plist"
    readonly pumaManagedPrefs

    pumaUserPrefs="/Library/Preferences/com.it.endpoint.puma.plist"
    readonly pumaUserPrefs

    # add check to download newest update plist

    # if the managed prefrences doesn't exist, exit non zero
    if [[ ! -f "${pumaManagedPrefs}" ]]; then
        echo "Managed Prefs Missing" >&2 
        exit 1
    fi

    # Check for swiftDialog, If not installed request the install from jamf via event trigger
    if [[ ! -e "/Library/Application Support/Dialog/Dialog.app" ]]; then
        echo "INFO: dialog not found, pull via Jamf" >&2
        jamf policy -event autopatch_swiftDialogSource -forceNoRecon
        sleep 3
    fi

}

# load configuration file information
loadConfiguration() {

    # Load the settings from the managed prefrences file first
    echo "INFO: Loading Configuration"

    DEBUG=$(defaults read "${pumaManagedPrefs}" DEBUG 2> /dev/null)
    
    silentModeEnabled=$(defaults read "${pumaManagedPrefs}" silentMode 2> /dev/null)
    
    patchDelay=$(defaults read "${pumaManagedPrefs}" patchDelay 2> /dev/null)
    
    patchEnforcement=$(defaults read "${pumaManagedPrefs}" patchEnforcement 2> /dev/null)
    
    storeNcheck=$(defaults read "${pumaManagedPrefs}" storeAndCheck 2> /dev/null)
    
    # Support App preference plist
    supportAppPrefsFileLocation=$(defaults read "${pumaManagedPrefs}" supportAppPrefsFileLocation 2> /dev/null) 
    
    # location for updates to be stored in pairs with version and app name
    plistPath=$(defaults read "${pumaManagedPrefs}" plistPath 2> /dev/null) 
    
    # get brandingimage from self service, users will have to open self service once for the custom image to load
    [[ $(defaults read "${pumaManagedPrefs}" brandIcon 2> /dev/null) == "SelfService" ]] && brandIcon="/Users/$LoggedInUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png" || brandIcon="$(defaults read "${pumaManagedPrefs}" brandIcon 2> /dev/null)"
    
    # get brandingheader from self service
    [[ $(defaults read "${pumaManagedPrefs}" brandHeader 2> /dev/null) == "SelfService" ]] && brandHeader="/Users/$LoggedInUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingheader.png" || brandHeader="$(defaults read "${pumaManagedPrefs}" brandHeader 2> /dev/null)"
    
    pilotUserFile=$(defaults read "${pumaManagedPrefs}" pilotUserFile 2> /dev/null)
    
    logLocation=$(defaults read "${pumaManagedPrefs}" logLocation 2> /dev/null)
    
    useNotificationCenter=$(defaults read "${pumaManagedPrefs}" useNotificationCenter 2> /dev/null)
    
    meetingDetection=$(defaults read "${pumaManagedPrefs}" meetingDetection 2> /dev/null)
    
    criticalOverrideMeetingDetection=$(defaults read "${pumaManagedPrefs}" criticalOverrideMeetingDetection 2> /dev/null)
    
    meetingReminders=$(defaults read "${pumaManagedPrefs}" meetingReminders 2> /dev/null)

    helpMenuText=$(defaults read "${pumaManagedPrefs}" helpMenuText 2> /dev/null)

    bannerText=$(defaults read "${pumaManagedPrefs}" bannerText 2> /dev/null)
    
    IFS=$' '
    backgroundScanSchedule=( $(defaults read "${pumaManagedPrefs}" backgroundScanSchedule 2> /dev/null | xargs | tr -d '(,)') )
    loudScanSchedule=( $(defaults read "${pumaManagedPrefs}" loudScanSchedule 2> /dev/null | xargs | tr -d '(,)') )
    IFS=$' \t\n\0'

    # Evaluate User Prefs
    echo "INFO: Loading User Prefs"
    
    # If the user preferences has a value and managed preferences doesn't have a value
    if [[ -n $(defaults read "${pumaUserPrefs}" useNotificationCenter 2> /dev/null) && -z "${useNotificationCenter}" ]]; then
        
        # Use the user preferences
        useNotificationCenter=$(defaults read "${pumaUserPrefs}" useNotificationCenter 2> /dev/null)

    # If user preferences are empty and managed preferences are empty
    elif [[ -z $(defaults read "${pumaUserPrefs}" useNotificationCenter 2> /dev/null) && -z "${useNotificationCenter}" ]]; then

        # Set to a default setting
        useNotificationCenter=0

    fi
    
    # If the user preferences has a value and managed preferences doesn't have a value
    if [[ -n $(defaults read "${pumaUserPrefs}" meetingDetection 2> /dev/null) && -z "${meetingDetection}" ]]; then

        # Use the user preferences
        meetingDetection=$(defaults read "${pumaUserPrefs}" meetingDetection 2> /dev/null)

    # If user preferences are empty and managed preferences are empty
    elif [[ -z $(defaults read "${pumaUserPrefs}" meetingDetection 2> /dev/null) && -z "${meetingDetection}" ]]; then
        
        # Set to a default setting
        meetingDetection=1
    
    fi

    # If the user preferences has a value and managed preferences doesn't have a value
    if [[ -n $(defaults read "${pumaUserPrefs}" criticalOverrideMeetingDetection 2> /dev/null) && -z "${criticalOverrideMeetingDetection}" ]]; then

        # Use the user preferences
        criticalOverrideMeetingDetection=$(defaults read "${pumaUserPrefs}" criticalOverrideMeetingDetection 2> /dev/null)

    # If user preferences are empty and managed preferences are empty
    elif [[ -z $(defaults read "${pumaUserPrefs}" criticalOverrideMeetingDetection 2> /dev/null) && -z "${criticalOverrideMeetingDetection}" ]]; then
        
        # Set to a default setting
        criticalOverrideMeetingDetection=0
    
    fi

    # If the user preferences has a value and managed preferences doesn't have a value
    if [[ -n $(defaults read "${pumaUserPrefs}" meetingReminders 2> /dev/null) && -z "${meetingReminders}" ]]; then

        # Use the user preferences
        meetingReminders=$(defaults read "${pumaUserPrefs}" meetingReminders 2> /dev/null)

    # If user preferences are empty and managed preferences are empty
    elif [[ -z $(defaults read "${pumaUserPrefs}" meetingReminders 2> /dev/null) && -z "${meetingReminders}" ]]; then

        # Set to a default setting
        meetingReminders=1

    fi

    # If Debug is enabled show output of full config
    if [[ "${DEBUG}" -eq 1 ]]; then
        logIt "DEBUG:INFO: List Configuration Loaded"
        logIt "DEBUG:INFO:DEBUG=$DEBUG"
        logIt "DEBUG:INFO:silentModeEnabled=$silentModeEnabled"
        logIt "DEBUG:INFO:patchDelay=$patchDelay"
        logIt "DEBUG:INFO:patchEnforcement=$patchEnforcement"
        logIt "DEBUG:INFO:storeNcheck=$storeNcheck"
        logIt "DEBUG:INFO:supportAppPrefsFileLocation=$supportAppPrefsFileLocation"
        logIt "DEBUG:INFO:plistPath=$plistPath"
        logIt "DEBUG:INFO:brandIcon=$brandIcon"
        logIt "DEBUG:INFO:brandHeader=$brandHeader"
        logIt "DEBUG:INFO:pilotUserFile=$pilotUserFile"
        logIt "DEBUG:INFO:logLocation=$logLocation"
        logIt "DEBUG:INFO:useNotificationCenter=$useNotificationCenter"
        logIt "DEBUG:INFO:meetingDetection=$meetingDetection"
        logIt "DEBUG:INFO:criticalOverrideMeetingDetection=$criticalOverrideMeetingDetection"
        logIt "DEBUG:INFO:meetingReminders=$meetingReminders"
        logIt "DEBUG:INFO:helpMenuText=$helpMenuText"
        logIt "DEBUG:INFO:bannerText=$bannerText"
        logIt "DEBUG:INFO:backgroundScanSchedule=${backgroundScanSchedule[*]}"
        logIt "DEBUG:INFO:loudScanSchedule=${loudScanSchedule[*]}"
    fi

    # If ran from self service log the event so it can be dashboarded
    if pgrep -a "JamfManagementService" >/dev/null 2>&1; then
        # PUMA was ran from Self Service
        logIt "INFO: PUMA triggered via Self Service"
        logIt "SPL:ShowUser=SS;t=$(date -ju +%s)"
        selfServiceFlag=1
    fi
}

# Log information about how this script was executed and put in it in $logLocation
logIt() {

  echo -e "$(date -ju +"%a %b %d %T") $(hostname -s) $(basename "$0")[$$]:$*" | tee -a "$logLocation"

}

# Wait for swift dialog and collect the exit code status
wait_for_dialog() {

    # Found this function here: https://www.baeldung.com/linux/background-process-get-exit-code
    # Pass a PID as argument 1 to this function and it will spit out the exit code once that process completes.
    # Also works if the process was already closed before this funciton runs.
    # The script pauses when this function is called and will not continue until a button is pressed.
    waitPID=$1
    [[ "${DEBUG}" != 0 ]] && logIt "DEBUG:INFO: Waiting for PID $waitPID to terminate"
    wait "$waitPID"
    dialogSelection=$?
    [[ "${DEBUG}" != 0 ]] && logIt "DEBUG:INFO: Dialog command with PID=$waitPID terminated with exit_code=$dialogSelection"
    return $dialogSelection

}

# Check if specific meeting apps are holding the computer from sleeping the display
check_for_meeting_apps() {

    logIt "DEBUG:INFO: Checking Meeting Active Status"

    # Get a list of processes preventing the computer from sleeping
    noSleepApps=$(pmset -g assertions | awk '/NoDisplaySleepAssertion | PreventUserIdleDisplaySleep/ && match($0,/\(.+\)/) && ! /coreaudiod/ {gsub(/^\ +/,"",$0); print};' | awk -F'[()]' '{print $2}')
        
    [[ "${DEBUG}" != 0 ]] && logIt "DEBUG:INFO: List Processes Preventing Sleep"
    [[ "${DEBUG}" != 0 ]] && logIt "DEBUG:INFO:Processes: $(echo "${noSleepApps}" | xargs)"

    # if the list of apps contains zoom.us log the information and set activeMeeting
    if [[ "${noSleepApps}" == *"zoom.us"* ]]; then
        logIt "WARN: Zoom meeting is Active"
        activeMeeting=1
    fi

    # if the list of apps contains Meeting Center from Webex log the information and set activeMeeting
    if [[ "${noSleepApps}" == *"Meeting Center"* ]]; then
        logIt "WARN: Webex meeting is Active"
        activeMeeting=1
    fi

    # if the list of apps contains Teams or MSTeams log the information and set activeMeeting
    if [[ "${noSleepApps}" == *"Teams"* ]] || [[ "${noSleepApps}" == *"MSTeams" ]]; then
        logIt "WARN: Teams meeting is Active"
        activeMeeting=1
    fi
}

# If ran from self service, show the user a nice No Updates dialog window
noUpdates() {

    # This function checks how PUMA was ran
    if [[ "${selfServiceFlag}" -eq 1 ]]; then
        # Log that PUMA was ran from Self Service
        [[ "${DEBUG}" != 0 ]] && logIt "DEBUG:INFO: PUMA triggered via Self Service"

        # will use custom notification or notification center based on useNotificationCenter
        [[ "${useNotificationCenter}" -eq 0 ]] && dialog --commandfile "$CommandFile" --hidedefaultkeyboardaction --ontop --moveable --bannerimage "$brandHeader" --bannertitle "${bannerText} Software Update" --titlefont "shadow=1" --alignment "center" --message '### No Updates  \nAll your apps are up to date.' --centericon --icon "SF=checkmark.circle.fill,palette=white,white,blue" --buttonstyle "center" --button1text "Close" --hidetimerbar --timer 15 || dialog --commandfile "$CommandFile" --notification --title "No Updates Available" --message "All your apps are up to date." 
    else
        # PUMA was ran from Jamf Binary / Check-in
        logIt "PUMA triggered via Jamf / Terminal"
        # do nothing if the policy is ran via Jamf and no apps are found.
    fi

    # go back to where this was ran from 
    return
}

### END 'Utility' Functions

# Check the configurated day of the week PUMA should run
## When ran from self service it will override the run schedule
scheduleCheck() {
    
    # log that we are checking if running from self service
    logIt "INFO: Checking override from Self Service"

    # If ran via self service, run both
    if [[ "${selfServiceFlag}" -eq 1 ]]; then

        # check to see if a meeting app is actively in a meeting
        ### Uncomment line below for meeting detection while running from self service
        # [[ "${meetingDetection}" -eq 1 ]] && check_for_meeting_apps 
        
        # attempt to update apps that are not running
        silentMode

        # Show the user update dialog windows
        loudMode

        # exit without error
        exit 0
    fi

    # log that we are comparing against configured schedule
    logIt "INFO: Comparing run schedule"

    # loop through each day in the array provided from backgroundScanSchedule
    for day in "${backgroundScanSchedule[@]}" ; do

        # Compare text in each array entry to see if it matches the day of the week local computer time
        if [[ "${day}" == $(date -j +%A) ]]; then
            
            # attempt to update apps that are not running
            silentMode

            # stop the loop since we got a match
            break

        fi

    done

    # loop through each day in the array provided from loudScanSchedule
    for day in "${loudScanSchedule[@]}" ; do

        # Compare text in each array entry to see if it matches the day of the week local computer time
        if [[ "${day}" == $(date -j +%A) ]]; then

            # check to see if a meeting app is actively in a meeting
            [[ "${meetingDetection}" -eq 1 ]] && check_for_meeting_apps 

            # Show the user update dialog windows
            loudMode 

            # exit or break to do next scheduled item
            exit 0 

        fi

    done
}

# Get the data required from the updatesAvailable PLIST
gotApps() {

    # First function to run after loading configuration, log if debug is enabled for this run
    [[ "${DEBUG}" != 0 ]] && logIt "######## DEBUG ENABLED ########"

    # get old IFS so it can be set back to it
    OLDIFS=$IFS

    # set separator to newlines
    IFS=$'\n'

    # add each key from plist as an item in the array
    updatesPlist=( $(xmllint -xpath "/plist/dict/key/text()" "$plistPath") )

    # get number of apps in the plist via this array
    numberofPlistItems="${#updatesPlist[@]}" 

    # set IFS back to its original setting
    IFS=$OLDIFS

    # Keep track of how many time ran through the whole loop 
    i=0 
    
    # Regex match for silentMode options per app
    regex='[0-4]'
    
    # Empty update arrays
    appsNeedingUpdates=()
    appsNeedingCriticalUpdates=()

    # Get the dictionary data for each application (version, apppath, timestamp)
    while [ $i -lt "$numberofPlistItems" ]; do
        
        # get each app version key into an array for comparision
        applicationPlistVersion[i]=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:Version" "$plistPath")

        # get each Application Path into an array for ease of use
        applicationPlistAppPath[i]=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:AppPath" "$plistPath")  
        
        # get each timestamp into an array for ease of use, or use the stored timestamp
        [[ "${useStoredTimeStamp[i]}" == 1 ]] && applicationPlistTimeStamp[i]=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:StoredTimeStamp" "$plistPath") || applicationPlistTimeStamp[i]=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:TimeStamp" "$plistPath")
        
        # get each Critical status into an array for ease of use
        applicationPlistCritical[i]=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:Critical" "$plistPath") 

        # get each Policy trigger for debugs sake, this is used as a different variable later on in the process
        applicationPlistPolicyTrigger[i]=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:PolicyTrigger" "$plistPath")

        # get the integer value if silent mode is enabled on the application entry
        applicationSilentMode[i]=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:SilentMode" "$plistPath" 2>/dev/null | xargs) 
        
        # if silent mode KVP doesn't match 0,1,2,3,4, set it to 0
        if [[ "{applicationSilentMode[i]}" =~ $regex ]]; then
            applicationSilentMode[i]=0
            [[ "${DEBUG}" != 0 ]] && logIt "WARN: SilentMode KVP NULL, disabling ${updatesPlist[$i]} SilentMode this run"
        fi

        # change IFS to new line to prevent separating on spaces and periods in appnames
        IFS=$'\n' 

        # Moving the displayname fillout to an earlier loop so it can be used elsewhere in the script.
        applicationDisplayName[i]=$(basename "$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:AppPath" "$plistPath")" | sed 's/.app//g') # grab the application basename without the .app for list display

        # change back to default 
        IFS=$' \t\n\0' 
        
        # Detection for if app is running
        isItRunning[i]=$(pgrep "${updatesPlist[$i]}" | awk 'END{print NF}') # will return 0 if there are no processes by the name of the application running
        
        # Use the AppPath to check if the user has the application before we start trying to grab the installed version
        if [[ -d "${applicationPlistAppPath[$i]}" ]]; then

            # This next line checks whats on the users computer based on the AppPath String in the array above
            applicationInstalledVersion[i]=$(plutil -extract "CFBundleShortVersionString" raw -o - "${applicationPlistAppPath[$i]}"/Contents/Info.plist) # get the LOCAL installed version for later comparision

        else
            
            # Log if the application is not found at the path provided
            logIt "WARN:${updatesPlist[$i]} NOT found at ${applicationPlistAppPath[$i]} Skipping"

        fi

        # Show all the data that was collected if Debug is enabled
        if [[ $DEBUG != 0 ]]; then
            logIt "DEBUG:INFO:Application=${updatesPlist[$i]}"
            logIt "DEBUG:INFO:App List Display Name=${applicationDisplayName[$i]}"
            logIt "DEBUG:INFO:Found=${updatesPlist[$i]} at ${applicationPlistAppPath[$i]}"
            logIt "DEBUG:INFO:Version=${applicationPlistVersion[$i]}"
            logIt "DEBUG:INFO:AppPath=${applicationPlistAppPath[$i]}"
            logIt "DEBUG:INFO:TimeStamp=${applicationPlistTimeStamp[$i]}"
            logIt "DEBUG:INFO:Critical=${applicationPlistCritical[$i]}"
            logIt "DEBUG:INFO:PolicyTrigger=${applicationPlistPolicyTrigger[$i]}"
            logIt "DEBUG:INFO:Installed app version=${applicationInstalledVersion[$i]}"
            logIt "DEBUG:INFO:Application Support Silent Mode=${applicationSilentMode[$i]}"
            logIt "DEBUG:INFO:Application Running greater than zero=${isItRunning[$i]}"
        fi

        # check to make sure the app exists / there is no bad values before comparing versions and adding to lists
        if [[ "${applicationPlistVersion[$i]}" != *"No such file or directory"* && "${applicationInstalledVersion[$i]}" != *"No such file or directory"* && -n "${applicationInstalledVersion[$i]}" ]]; then

            # Use printf to print the two versions on separate lines, then use sort to sort the lowest one to the top
            if [[ "$(printf '%s\n' "${applicationPlistVersion[$i]}" "${applicationInstalledVersion[$i]}" | sort -V | head -n1)" = "${applicationPlistVersion[$i]}" ]]; then

                # Log that the installed version is greater or equal to the plist version
                logIt "INFO: Installed version ${applicationInstalledVersion[$i]} is greater than or equal to the plist version ${applicationPlistVersion[$i]}" 

            else

                # Log that the installed version needs to be patch
                logIt "INFO: Installed version ${applicationInstalledVersion[$i]} is less than ${applicationPlistVersion[$i]}" 

                # Calculate the time since the patch was updated in the plist file
                plistTimeDifference[i]=$(( currentTime - ${applicationPlistTimeStamp[$i]} )) 

                # log the difference from when the PU for specific app was updated vs current time
                logIt "INFO: TimeStamp Difference ${plistTimeDifference[$i]}" 

                # Check for critical update, pilot user, or past the 48hrs
                if [[ "${plistTimeDifference[$i]}" -gt $patchEnforcement || -f $pilotUserFile || "${applicationPlistCritical[$i]}" = "true" ]]; then 
                    
                    # log that this update is qualified as a critical update that cannot be deferred
                    logIt "Add the application(s) to the critical update list"

                    # add the apps that need critical(force installed) updates to a seprate array
                    appsNeedingCriticalUpdates[i]="${updatesPlist[$i]}"

                # If the App is past the 2 hour patch delay
                elif [[ "${plistTimeDifference[$i]}" -gt $patchDelay ]]; then

                    # Log that the update is available but not forced    
                    logIt "Non critical updates"

                    # Add app entry to updatesPlist
                    appsNeedingUpdates[i]="${updatesPlist[$i]}"

                    # Calculate deadline for end user display
                    appsDeadlineSeconds[i]=$(( ${applicationPlistTimeStamp[$i]} + patchEnforcement - 86400 ))

                    # Create Human Readable format of deadline
                    appsDeadlineReadable[i]=$( date -jf %s "${appsDeadlineSeconds[$i]}" +"%a %b %d" )

                    logIt "Deadline Readable:${appsDeadlineReadable[$i]}"

                else
                    
                    # log that we are doing nothing with this application
                    logIt "######## No Patch Do Nothing ########"

                fi
            fi
        else
            
            # Log if the application is not found at the path provided
            logIt "${updatesPlist[$i]} NOT found at ${applicationPlistAppPath[$i]} Skipping"

        fi

        # add 1 for next iteration of this loop
        i=$((i+1)) 
    done
}

# Check what apps are running and update if they are not
silentMode() {

    # Log update stats before starting silentMode
    if [[ "${DEBUG}" != 0 ]]; then
        logIt "######## Silent Mode Precheck ########"
        logIt "Standard Update Count: ${#appsNeedingUpdates[@]}"
        logIt "Critical Update Count: ${#appsNeedingCriticalUpdates[@]}" 
        logIt "Standard Updates: " "${appsNeedingUpdates[@]}"
        logIt "Critical Updates: " "${appsNeedingCriticalUpdates[@]}"
        logIt "Updates: " "${appsNeedingUpdates[@]}" "${appsNeedingCriticalUpdates[@]}"
    fi
    
    # Currently Support States for
    # "${silentModeEnabled}""
    # 0 = disabled do not update in silent mode
    # 1 = enabled update in silent mode
    # Not Implemented # 3 = force update in silent mode 
    # Not Implemented # 4 = force update in silent mode and Do not notify

    # Only run this if SilentMode is enabled in the preferences file
    if [[ "${silentModeEnabled}" = 1 ]]; then

        logIt "INFO: SILENT MODE START"

        [[ "${DEBUG}" != 0 ]] && logIt "DESC: Will attempt to update applications that are not currently open"

        # Run through the following if there are any updates, critical or not.
        if [[ "${#appsNeedingCriticalUpdates[@]}" -gt 0 ]] || [[ "${#appsNeedingUpdates[@]}" -gt 0 ]]; then
            
            # Logging Specific to Splunk so data can be pulled easily
            logIt "SPL:ShowUser=SL;t=$(date -ju +%s)"
            
            # If the useNotificationCenter KVP is enabled it will use Notification center instead of the custom loading animation mini window
            [[ "${useNotificationCenter}" -eq 0 ]] && dialog --commandfile "$CommandFile" --moveable --mini --position topright --title "Updates Found" --message "Checking Open Applications" --icon "${brandIcon}" --progress "$numberOfUpdates" & sleep 2 || dialog --commandfile "$CommandFile" --notification --title "Updates Found" --message "Checking Open Applications" # show the user that stuff is happening
            
            # Only update the Progress bar if the custom mini window is in use.
            [[ "${useNotificationCenter}" -eq 0 ]] && echo "progress: $u" >> "$CommandFile" #start the progress bar at 0
            
            # Check if critical applications need to update
            if [[ "${#appsNeedingCriticalUpdates[@]}" -gt 0 ]]; then
                
                # Change to local variable
                numberOfUpdates=${#appsNeedingCriticalUpdates[@]}
                
                # Whole Loop iteration
                i=0
                
                # Update Loop iteration
                u=0

                # Loop through the populated and empty array values for what apps are available for critical updates
                while [[ $u -lt $numberOfUpdates ]] && [[ $i -lt $numberofPlistItems ]]; do

                    # check if the specific array entry is empty
                    if [[ -z "${appsNeedingCriticalUpdates[$i]}" ]]; then 
                        
                        # debugging log empty array to track how many items are empty
                        [[ "${DEBUG}" != 0 ]] && logIt "empty array $i entry ${appsNeedingCriticalUpdates[$i]}"
                        
                        # get rid of the empty array element
                        unset "appsNeedingCriticalUpdates[$i]"

                    else
                        
                        # debugging log array entry that has a value
                        [[ "${DEBUG}" != 0 ]] && logIt "app array entry ${appsNeedingCriticalUpdates[$i]}"

                            # future development to take advatange of the additional options for silentmode 3 / 4

                        # check if the app is running and if it supports silent mode in the plist
                        if [[ "${isItRunning[$i]}" = 0 ]] && [[ "${applicationSilentMode[$i]}" -gt 0 ]]; then

                            # Check if the user is using Notification Center
                            if [[ "${useNotificationCenter}" -eq 0 ]]; then

                                # Update the user facing dialog with the application name
                                echo "message: ${applicationDisplayName[$i]} is updating" >> "$CommandFile"

                                # Update the icon in the user facing dialog
                                echo "overlayicon: ${applicationPlistAppPath[$i]}" >> "$CommandFile"

                            else
                                
                                # update the custom mini dialog loading window if notification center is not enabled
                                dialog --commandfile "$CommandFile" --notification --title "Patch Update Manager" --message "${applicationDisplayName[$i]} is Updating"

                            fi

                            # human reaction time before apps start closing
                            sleep 1

                            # request the install via the policy trigger in the application labeled dictionary in the plist
                            jamf policy -event "${applicationPlistPolicyTrigger[$i]}" -forceNoRecon
                            
                            # get rid of the array item as we performed the update
                            unset "appsNeedingCriticalUpdates[$i]"

                        fi

                        # add 1 to the attempt update loop
                        u=$((u+1))

                    fi

                    # add 1 for the iteration of this loop
                    i=$((i+1))
                
                # End the Loop through the critical updates array
                done

                # human reaction time before starting the next loop
                sleep 1

            # End Check for critical updates
            fi
            
            # Check if applications need to be updated that are not flagged as critical
            if [[ "${#appsNeedingUpdates[@]}" -gt 0 ]]; then

                # There are non critical updates available
                numberOfUpdates=${#appsNeedingUpdates[@]}
                
                # Whole Loop iteration
                i=0

                # Update Loop iteration
                u=0
                
                # Loop through the populated and empty array values for what apps are available for updates
                while [[ $u -lt $numberOfUpdates ]] && [[ $i -lt $numberofPlistItems ]]; do

                    # check if the specific array entry is empty
                    if [[ -z "${appsNeedingUpdates[$i]}" ]]; then

                        # debugging log empty arrays to track how many items are empty
                        [[ "${DEBUG}" != 0 ]] && logIt "empty array $i entry ${appsNeedingUpdates[$i]}" 

                        # get rid of the empty array element
                        unset "appsNeedingUpdates[$i]" 

                    else

                        # debugging log array entry that has a value
                        [[ "${DEBUG}" != 0 ]] && logIt "app array entry ${appsNeedingUpdates[$i]}"

                            # future development to take advatange of the additional options for silentmode 3 / 4

                        # check if the app is running and if it supports silent mode in the plist
                        if [[ "${isItRunning[$i]}" = 0 ]] && [[ "${applicationSilentMode[$i]}" -gt 0 ]]; then

                            # Check if the user is using Notification Center
                            if [[ "${useNotificationCenter}" -eq 0 ]]; then
                            
                                # Update the user facing dialog with the application name
                                echo "message: ${applicationDisplayName[$i]} is updating" >> "$CommandFile"

                                # Update the icon in the user facing dialog
                                echo "overlayicon: ${applicationPlistAppPath[$i]}" >> "$CommandFile"

                            else

                                dialog --commandfile "$CommandFile" --notification --title "Patch Update Manager" --message "${applicationDisplayName[$i]} is Updating"

                            fi

                            # human reaction time
                            sleep 1

                            # request the install via the policy trigger
                            jamf policy -event "${applicationPlistPolicyTrigger[$i]}" -forceNoRecon

                            # get rid of the array item as we performed the update
                            unset "appsNeedingUpdates[$i]"

                        fi

                        # add 1 to the attempt update loop
                        u=$((u+1))

                    fi

                    # add 1 for next iteration of this loop
                    i=$((i+1)) 

                done

                # reaction time
                sleep 1 

            fi

            # send quit command to swift dialog to close any open dialogs
            echo "quit:" >> "$CommandFile"

            # reaction time
            sleep 1

            # Cleanup Dialog file
            rm -rf "${CommandFile}" 

        fi

    else

        # log that silent mode is disabled
        logIt "INFO: Silent Mode is not currently enabled"

    fi

    # log that we finished silentMode
    logIt "INFO: SILENT MODE DONE"

    # go back to where this function was called from
    return
}

# START SHOWING THE USER STUFF
loudMode() {

    # Log update stats before starting silentMode
    if [[ $DEBUG != 0 ]]; then
        logIt "######## START LOUD MODE ########"
        logIt "Standard Update Count: ${#appsNeedingUpdates[@]}"
        logIt "Critical Update Count: ${#appsNeedingCriticalUpdates[@]}" 
        logIt "Standard Updates: " "${appsNeedingUpdates[@]}"
        logIt "Critical Updates: " "${appsNeedingCriticalUpdates[@]}"
        logIt "Updates: " "${appsNeedingUpdates[@]}" "${appsNeedingCriticalUpdates[@]}"
    fi
    
    # log that we are starting loud mode
    logIt "INFO: LOUD MODE START"
    [[ "${DEBUG}" != 0 ]] && logIt "DESC: Will Show users two update lists Critical Updates first, then recommended updates."

    # Critical Meeting overrides enabled?
    if [[ "${criticalOverrideMeetingDetection}" -eq 0 ]]; then

        # Active Meeting with updates available
        if [[ "${#appsNeedingCriticalUpdates[@]}" -gt 0 || "${#appsNeedingUpdates[@]}" -gt 0 ]] && [[ "${activeMeeting}" -gt 0 ]]; then

            # specific logging for splunk to pickup
            logIt "SPL:ShowUser=MT;t=$(date -ju +%s)"

            # alert the user via support app
            defaults write "${supportAppPrefsFileLocation}" ExtensionAlertA -bool true

            # check if meeting reminders are enabled
            if [[ "${meetingReminders}" -eq 1 ]]; then     
                
                # check if notification center is enabled
                if [[ "${useNotificationCenter}" -eq 0 ]]; then

                    # display custom mini dialog window
                    dialog --commandfile "$CommandFile" --mini --ontop --moveable --position "topright" --icon "SF=phone.circle.fill,palette=white,#F58220,#F58220" --title "Updates Available" --message "Please visit Self Service and run \"Check for Updates\"   \n   \nPatch Update Manager will try again later." --button1text "Okay" --hidetimerbar --timer 30

                else

                    # display notification center notification
                    dialog --commandfile "$CommandFile" --notification --title "Updates Available" --message "Please check for updates via menu bar  \nPUMA will try again later."

                fi

            fi

            # Exit PUMA run
            exit 0

        fi

    fi

    # If there are any critical updates in the array do something
    if [[ "${#appsNeedingCriticalUpdates[@]}" -gt 0 ]]; then

        # specific logging for splunk to pickup
        logIt "SPL:ShowUser=CL;t=$(date -ju +%s)"

        # Show pretty list of updates that are required to be installed

        # If the helpMenuText contains something, enabled the help window
        if [[ -n "${helpMenuText}" ]]; then
            # Display the list window without anything in the list, use commandfile to list apps, with help message
            dialog --commandfile "$CommandFile" --hidedefaultkeyboardaction --ontop --moveable --bannerimage "$brandHeader" --bannertitle "Critical ${bannerText} Software Update" --titlefont "shadow=1,colour=#F58220" --message none --icon none --messagefont "size=16" --helpmessage "${helpMenuText}" --button1text "Quit Apps and Update Now" --timer 900 & sleep 1.5 
        else
            # Display the list window without anything in the list, use commandfile to list apps, no help window
            dialog --commandfile "$CommandFile" --hidedefaultkeyboardaction --ontop --moveable --bannerimage "$brandHeader" --bannertitle "Critical ${bannerText} Software Update" --titlefont "shadow=1,colour=#F58220" --message none --icon none --messagefont "size=16" --button1text "Quit Apps and Update Now" --timer 900 & sleep 1.5 
        fi

        # get the processID from switfDialog so we can wait for it to close
        dialogPID=$! 

        # Get the number of updates from items in the array
        numberOfUpdates=${#appsNeedingCriticalUpdates[@]} 

        # add line to the commandfile so user sees a pretty list, for more info about how to use commandfile and swiftdialog check the swiftdialog github
        echo "list: Critical updates will be installed for the following Applications: " >> "$CommandFile" 
        
        # Keep track of how many time ran through the whole loop
        i=0 

        # Keep track of how many times we run trough the UPDATE part of the loop
        u=0 
        
        # log that we are showing the user a list of updates
        logIt "#### Creating pretty list for end user"

        # LOOP
        # Iterate through the array of critical updates till one of the following conditions is met
        ## $u is equal to the numberOfUpdates declared earlier by getting the number of array items in appsNeedingCriticalUpdates array
        ## $i is equal to 20, meaning it has ran through the loop 20 times, this is a safeguard from runaway loops
        
        while [[ $u -lt $numberOfUpdates ]] && [[ $i -lt $numberofPlistItems ]]; do

            # check if the array is empty
            if [[ -z "${appsNeedingCriticalUpdates[$i]}" ]]; then

                # debugging echo out empty array to make sure it is empty and track how many items are empty
                [[ $DEBUG != 0 ]] && logIt "empty array $i entry ${appsNeedingCriticalUpdates[$i]}"

                # get rid of the empty array element
                unset "appsNeedingCriticalUpdates[$i]" 

            else

                # debug log of what is being listed
                [[ $DEBUG != 0 ]] && logIt "app array entry ${applicationDisplayName[$i]}"

                # add that app to the commandfile so user sees a pretty list
                echo "listitem: add, title: ${applicationDisplayName[$i]}, icon: ${applicationPlistAppPath[$i]}, status: pending, statustext: Pending Force Update" >> "$CommandFile"

                # add 1 to count updates for array items that are not empty
                u=$((u+1)) 

            fi

            # add 1 for next iteration of this loop
            i=$((i+1))

        done

        # Keep track of how many time ran through the whole loop
        i=0 

        # Keep track of how many times we run trough the UPDATE part of the loop
        u=0 

        # wait till the swift dialog process to end
        wait $dialogPID 

        # Cleanup Dialog file
        rm -rf "${CommandFile}" 

        # Critical Updates don't care what the exit code is, just start updating after this wait

        # Open the mini window with the update progress to let users know we are starting updates
        dialog --commandfile "$CommandFile" --ontop --moveable --mini --position topright --title "Updates in Progress" --message "Gathering Applications" --icon "${brandIcon}" --progress "$numberOfUpdates" & sleep 2
        
        #start the progress bar at 0
        echo "progress: $u" >> "$CommandFile" 
        
        # LOOP
        # Iterate through the array of critical updates till one of the following conditions is met
        ## $u is equal to the numberOfUpdates declared earlier by getting the number of array items in appsNeedingCriticalUpdates array
        ## $i is equal to 20, meaning it has ran through the loop 20 times, this is a safeguard from runaway loops

        while [[ $u -lt $numberOfUpdates ]] && [[ $i -lt $numberofPlistItems ]]; do

            # check if the array is empty
            if [[ -z "${appsNeedingCriticalUpdates[$i]}" ]]; then 
                
                # debugging echo out empty array to make sure it is empty and track how many items are empty
                [[ "${DEBUG}" != 0 ]] && logIt "empty array $i entry ${appsNeedingCriticalUpdates[$i]}" 
                
                # get rid of the empty array element
                unset "appsNeedingCriticalUpdates[$i]" 

            else

                # log the app we are updating
                [[ "${DEBUG}" != 0 ]] && logIt "app array entry ${appsNeedingCriticalUpdates[$i]}"
                
                # add 1 to count updates for array items that are not empty
                u=$((u+1))

                # update the dialog message to match the application we are updating
                echo "message: ${applicationDisplayName[$i]} is updating" >> "$CommandFile"
                
                # update the dialog icon to match the application we are updating
                echo "overlayicon: ${applicationPlistAppPath[$i]}" >> "$CommandFile"

                # human reaction time
                sleep 1

                #kill the application the name is based off of the label used in the array
                killall "${appsNeedingCriticalUpdates[$i]}" 

                # Get the status of the killall command
                applicationKillStatus="$?"

                # request the install via the policy trigger in the plist
                jamf policy -event "${applicationPlistPolicyTrigger[$i]}" -forceNoRecon 

                # log the trigger that was used to install
                logIt "trigger ${applicationPlistPolicyTrigger[$i]}"
                
                # update the progress bar
                echo "progress: $u" >> "$CommandFile"

                # This means the app was open and was killed for the user, open it back up for them
                [[ $applicationKillStatus = 0 ]] && open -a "${appsNeedingCriticalUpdates[$i]}"

            fi

            # add 1 for next iteration of this loop
            i=$((i+1))

        done

        # human reaction time
        sleep 1

        # send quit command to close all open dialog windows
        echo "quit:" >> "$CommandFile"

    fi

    # Check after critical updates have run if we need to notify and quit due to an active meeting and criticalOverride enabled
    if [[ "${criticalOverrideMeetingDetection}" -eq 1 ]]; then
        
        # Check for non critical updates and an active meeting
        if [[ "${#appsNeedingUpdates[@]}" -gt 0 ]] && [[ "${activeMeeting}" -gt 0 ]]; then

            # specific loggin for splunk to pickup
            logIt "SPL:ShowUser=MT;t=$(date -ju +%s)"

            # alert the user via support app
            defaults write "${supportAppPrefsFileLocation}" ExtensionAlertA -bool true

            # check if meeting reminder are enabled 
            if [[ "${meetingReminders}" -eq 1 ]]; then

                # check if notification center is enabled
                if [[ "${useNotificationCenter}" -eq 0 ]]; then

                    # display custom mini dialog window
                    dialog --commandfile "$CommandFile" --mini --ontop --moveable --position "topright" --icon "SF=phone.circle.fill,palette=white,#F58220,#F58220" --title "Updates Available" --message "Please visit Self Service and run \"Check for Updates\"   \n   \nPatch Update Manager will try again later." --button1text "Okay" --hidetimerbar --timer 30

                else

                    # display notification center notification
                    dialog --commandfile "$CommandFile" --notification --title "Updates Available" --message "Please check for updates via menu bar  \nPUMA will try again later."

                fi

            fi

            # Exit PUMA run
            exit 0

        fi

    fi

    # If there are any regular updates (not forced) in the array do something
    if [[ "${#appsNeedingUpdates[@]}" -gt 0 ]]; then

        # specific logging for splunk to pickup
        logIt "SPL:ShowUser=RL;t=$(date -ju +%s)"

        # If there are non critical updates trigger the support app notification
        defaults write "${supportAppPrefsFileLocation}" ExtensionAlertA -bool true

        # go through the 'appsNeedingUpdates' array and show items as pretty list and give option to update

        # If the helpMenuText contains something, enabled the help window
        if [[ -n "${helpMenuText}" ]]; then
            # Display the list window without anything in the list, use commandfile to list apps, with help window
            dialog --commandfile "$CommandFile" --hidedefaultkeyboardaction --ontop --moveable --bannerimage "$brandHeader" --bannertitle "${bannerText} Software Update" --titlefont "shadow=1" --message none --icon none --messagefont "size=16" --helpmessage "${helpMenuText}" --helpicon none --button1text "Quit Apps and Update Now" --button2text "Update Later" --hidetimerbar --timer 900 & sleep 1.5
        else
            # Display the list window without anything in the list, use commandfile to list apps, no help window
            dialog --commandfile "$CommandFile" --hidedefaultkeyboardaction --ontop --moveable --bannerimage "$brandHeader" --bannertitle "${bannerText} Software Update" --titlefont "shadow=1" --message none --icon none --messagefont "size=16" --button1text "Quit Apps and Update Now" --button2text "Update Later" --hidetimerbar --timer 900 & sleep 1.5
        fi

        # get the processID from switfDialog so we can wait for it to close
        dialogPID=$!

        # Get the number of updates from items in the array
        numberOfUpdates=${#appsNeedingUpdates[@]}

        # add line to the commandfile so user sees a pretty list, for more info about how to use commandfile and swiftdialog check the swiftdialog github
        echo "list: " >> "$CommandFile"

        # Keep track of how many time ran through the whole loop
        i=0 

        # Keep track of how many times we run trough the UPDATE part of the loop
        u=0

        # log that we are showing the user a list of updates
        logIt "#### Creating pretty list for end user"

        # Iterate through a the array appsNeedingUpdates and see if there are non required updates available
        ## $u is equal to the numberOfUpdates declared earlier by getting the number of array items in appsNeedingUpdates array
        ## $i is equal to 20, meaning it has ran through the loop 20 times, this is a safeguard from runaway loops

        while [[ $u -lt $numberOfUpdates ]] && [[ $i -lt $numberofPlistItems ]]; do

            # check if the array is empty
            if [[ -z "${appsNeedingUpdates[$i]}" ]]; then

                # debugging echo out empty array to make sure it is empty and track how many items are empty
                [[ $DEBUG != 0 ]] && logIt "empty array entry ${appsNeedingUpdates[$i]}" 

                # get rid of the empty array element
                unset "appsNeedingUpdates[$i]"

            else
            
                # debug log of what is being listed
                [[ $DEBUG != 0 ]] && logIt "app array entry ${applicationDisplayName[$i]}"

                # add that app to the commandfile so user sees a pretty list
                echo "listitem: add, title: ${applicationDisplayName[$i]}, icon: ${applicationPlistAppPath[$i]}, status: none, statustext: Patch will be enforced after ${appsDeadlineReadable[$i]}" >> "$CommandFile" 

                # add 1 to count updates when they are found
                u=$((u+1))

            fi

            # add 1 for next iteration of this loop
            i=$((i+1))

        done

        # human reaction time
        sleep 1 

        # wait for the swift dialog process to end and get the exit code from the window
        wait_for_dialog $dialogPID

        # Cleanup Dialog file
        rm -rf "${CommandFile}" 

        # based on the exit code from swift dialog, perform the following
        case "$dialogSelection" in
            0)
                # log the button that was pressed
                logIt "User selected force quit and update all apps"

                # Keep track of how many time ran through the whole loop
                i=0 

                # Keep track of how many times we run trough the UPDATE part of the loop
                u=0

                # Open the mini window with the update progress to let users know we are starting updates
                dialog --commandfile "$CommandFile" --ontop --moveable --mini --position topright --title "Updates in Progress" --message "Gathering Applications" --alignment centered --icon "${brandIcon}" --progress "$numberOfUpdates" & sleep 2

                # start the progress bar at 0
                echo "progress: $u" >> "$CommandFile" 

                # Iterate through a the array appsNeedingUpdates and see if there are non required updates available
                ## $u is equal to the numberOfUpdates declared earlier by getting the number of array items in appsNeedingUpdates array
                ## $i is equal to 20, meaning it has ran through the loop 20 times, this is a safeguard from runaway loops

                while [[ $u -lt $numberOfUpdates ]] && [[ $i -lt $numberofPlistItems ]]; do

                    # check for empty array items
                    if [[ -z "${appsNeedingUpdates[$i]}" ]]; then

                        # debugging echo out empty array to make sure it is empty and track how many items are empty
                        [[ $DEBUG != 0 ]] && logIt "empty array entry ${appsNeedingUpdates[$i]}"

                        # get rid of the empty array element
                        unset "appsNeedingUpdates[$i]"

                    else

                        # log the app we are updating
                        [[ $DEBUG != 0 ]] && logIt "app array entry ${appsNeedingUpdates[$i]}"

                        # add 1 to count updates when they are found
                        u=$((u+1)) 

                        # update the dialog message to match the application we are updating
                        echo "message: ${applicationDisplayName[$i]} is updating" >> "$CommandFile"
                        
                        # update the dialog icon to match the application we are updating
                        echo "overlayicon: ${applicationPlistAppPath[$i]}" >> "$CommandFile"

                        # human reaction time
                        sleep 1

                        #kill the application the name is based off of the label used in the array
                        killall "${appsNeedingUpdates[$i]}" 

                        # Get the status of the killall command
                        applicationKillStatus="$?"

                        # request the install via the policy trigger in the plist
                        jamf policy -event "${applicationPlistPolicyTrigger[$i]}" -forceNoRecon 

                        # log the trigger that was used to install
                        logIt "trigger ${applicationPlistPolicyTrigger[$i]}"
                        
                        # update the progress bar
                        echo "progress: $u" >> "$CommandFile"

                        # This means the app was open and was killed for the user, open it back up for them
                        [[ $applicationKillStatus = 0 ]] && open -a "${appsNeedingUpdates[$i]}"

                    fi

                    # add 1 for next iteration of this loop
                    i=$((i+1))

                done

                # human reaction time
                sleep 1 

                # send quit command to close all open dialog windows
                echo "quit:" >> "$CommandFile"

                ;;
            2)

                logIt "user chose update later"

                ;;
            3)
                
                # Leaving this open for button 3 to eventually come back
                ## Maybe as settings button
                
                logIt "user chose info button"
                
                exit 0

                ;;
            4)

                logIt "Dialog has timed out"
                
                exit 0

                ;;
            10)

                logIt "User quit the dialog popup"

                ;;
            *)
                
                logIt "Dialog exited with unexpected code: $dialogSelection"

                exit 1
                
                ;;
        esac
    fi

    # If there are no updates, run the function to show the user there are no updates
    if [[ "${#appsNeedingCriticalUpdates[@]}" -eq 0 ]] && [[ "${#appsNeedingUpdates[@]}" -eq 0 ]]; then
        
        # remove support app alerts
        defaults write "${supportAppPrefsFileLocation}" ExtensionAlertA -bool false

        # run the noUpdates function to notify the user if ran via self service
        noUpdates

        # exit
        exit 0
    fi

}

# mark what apps and what versions and when the user saw them first
storeCheck() {

    # Only run if storeNcheck is true
    if [[ "${storeNcheck}" -gt 0 ]]; then

        if [[ "${#appsNeedingUpdates[@]}" -gt 0 ]]; then
        
            # Keep track of how many time ran through the whole loop
            i=0 

            # Keep track of how many times we run trough the UPDATE part of the loop
            u=0 

            # Keep track if we need to rerun gotApps
            reRunGotApps=0

            # check recommended updates, not checking critical updates as they are already required
            while [[ $u -lt "${#appsNeedingUpdates[@]}" ]] && [[ $i -lt $numberofPlistItems ]]; do
                
                # check if the array is empty
                if [[ -z "${appsNeedingUpdates[$i]}" ]]; then
                    
                    # debugging echo out empty array to make sure it is empty and track how many items are empty
                    [[ "${DEBUG}" != 0 ]] && logIt "This array item is empty"
                
                else
                    # If the app is in this list, the app is installed and needs to update.
                    # Check if the stored version exists and if it is lower than the current update.

                    # get the stored version from the plist if it exists
                    storedVersion[i]+=$(/usr/libexec/PlistBuddy -c "print ${updatesPlist[$i]// /\\ }:StoredVersion" "$plistPath")

                    # if the app entry doesn't have a stored version
                    if [[ -z "${storedVersion[$i]}" ]]; then

                        # log what app had an empty stored version 
                        [[ "${DEBUG}" != 0 ]] && logIt "${updatesPlist[$i]} Store Versions is empty, storing version and timestamp"
                        
                        # Create the stored version entry
                        /usr/libexec/PlistBuddy -c "add ${updatesPlist[$i]// /\\ }:StoredVersion string" "$plistPath"

                        # Populate the value for the Stored Version
                        /usr/libexec/PlistBuddy -c "set ${updatesPlist[$i]// /\\ }:StoredVersion ${applicationPlistVersion[$i]}" "$plistPath"

                        # Create the stored time stamp entry
                        /usr/libexec/PlistBuddy -c "add ${updatesPlist[$i]// /\\ }:StoredTimeStamp integer" "$plistPath"

                        # Populate the value for the Stored Version
                        /usr/libexec/PlistBuddy -c "set ${updatesPlist[$i]// /\\ }:StoredTimeStamp ${applicationPlistTimeStamp[$i]}" "$plistPath"

                    else

                        # log what app has what in stored version
                        [[ "${DEBUG}" != 0 ]] && logIt "${updatesPlist[$i]} Stored Version contains ${storedVersion[$i]}"

                        # First compare is the stored version less than the version in the plist
                        if [[ "$(printf '%s\n' "${applicationPlistVersion[$i]}" "${storedVersion[$i]}" | sort -V | head -n1)" = "${storedVersion[$i]}" ]]; then

                            # log that the plist version is great than or equal to the stored version
                            [[ "${DEBUG}" != 0 ]] && logIt "${applicationPlistVersion[$i]} plist version is greater than or equal to stored Version ${storedVersion[$i]}"

                            # Now check is the stored version less than what is installed
                            if [[ "$(printf '%s\n' "${storedVersion[$i]}" "${applicationInstalledVersion[$i]}" | sort -V | head -n1)" = "${storedVersion[$i]}" ]]; then

                                # log that the installed version is greater than or equal to the stored version
                                [[ "${DEBUG}" != 0 ]] && logIt "Installed Version ${applicationInstalledVersion[$i]} is greater than or equal to the stored version ${storedVersion[$i]}"

                                # If we are here these should already exist in the plist no need to use add command

                                # Populate the value for the Stored Version
                                /usr/libexec/PlistBuddy -c "set ${updatesPlist[$i]// /\\ }:StoredVersion ${applicationPlistVersion[$i]}" "$plistPath"

                                # Populate the value for the Stored Version
                                /usr/libexec/PlistBuddy -c "set ${updatesPlist[$i]// /\\ }:StoredTimeStamp ${applicationPlistTimeStamp[$i]}" "$plistPath"

                            else

                                # debug logging for versions
                                [[ "${DEBUG}" != 0 ]] && logIt "Installed Version ${applicationInstalledVersion[$i]} is less than the stored version ${storedVersion[$i]}"
                                
                                # set application specific variable to use the stored time stamp
                                useStoredTimeStamp[i]+="1"

                                # set to 1 so we can flag outside of the loop that we need to run gotApps
                                reRunGotApps=1

                            fi

                        fi

                    fi

                    # add 1 to count updates for array items that are not empty
                    u=$((u+1))

                fi
                
                # add 1 for next iteration of this loop
                i=$((i+1))

            done

            # check if we need to run gotApps again 
            [[ "${reRunGotApps}" -eq 1 ]] && gotApps

        fi

    fi

}

preCheck # check if required systems are in place + house keeping
loadConfiguration # check preference files
gotApps # check the plist and installed versions
storeCheck # check for stored versions
scheduleCheck # parse the preference file to see what days PUMA should run
# These are handled by scheduleCheck function now
    # silentMode # attempt to update apps that are not running
    # check_for_meeting_apps # check to see if a meeting app is actively in a meeting
    # loudMode # Show the user update dialog windows