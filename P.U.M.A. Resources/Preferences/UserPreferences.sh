#!/bin/bash

# 'Simple' swift dialog screen to configure user preferences for testing

LoggedInUser=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }') # Get the user logged into the computer
readonly LoggedInUser
brandIcon="/Users/$LoggedInUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingimage.png"
brandHeader="/Users/$LoggedInUser/Library/Application Support/com.jamfsoftware.selfservice.mac/Documents/Images/brandingheader.png"
# Generate unique commandfile
## To use the command file add following to dialog ## --commandfile "$CommandFile"
CommandFile="/var/tmp/$(uuidgen | sed 's/-//g').dialog.log" 
pumaUserPrefs="/Library/Preferences/com.it.endpoint.puma.plist"

# Reset On Every Run
rm -rf "${pumaUserPrefs}"

dialog --commandfile "${CommandFile}" --bannerimage "${brandHeader}" --bannertitle "WARNING" --titlefont "shadow=1" --height 200 --width 600 --message "All user settings are reset when this is ran.<br/>If you do not want to change any settings press cancel on the next screen" --messagefont "size=16,colour=#F58220" --hidetimerbar --ontop --moveable --timer 10

dialogReturned=$(dialog \
    --commandfile "${CommandFile}" \
	--hidetimerbar \
	--ontop \
	--moveable \
    --height 355 \
    --width 800 \
	--bannerimage "${brandHeader}" \
	--bannertitle "PUMA User Configuration" \
	--icon "${brandIcon}" \
	--titlefont "shadow=1" \
    --message "Please make any changes to the current configuration." \
    --button1text "Next" \
	--button2text "Cancel" \
	--messagefont "size=16,colour=#F58220" \
	--checkboxstyle switch \
    --checkbox "Meeting Update Reminders",checked \
    --checkbox "Critical Updates Override Meeting Call Detections" \
    --checkbox "Use Notification Center" \
    --message "Cancel if you do not want to make changes" \
    --timer 600 \
	--quitkey X)

if [[ -n "${dialogReturned}" ]]; then 
    if [[ $(echo "${dialogReturned}" | sed 's/"//g' | grep "Use Notification Center" | awk -F " : " '{print $NF}') == "true" ]]; then
        echo "User Made changes Use Notification Center"
        flag=1
    fi
    if [[ $(echo "${dialogReturned}" | sed 's/"//g' | grep "Critical Updates Override Meeting Call Detections" | awk -F " : " '{print $NF}') == "true" ]]; then
        echo "User Made changes Critical Overrides Meeting Call Detections"
        flag=1
    fi
    if [[ $(echo "${dialogReturned}" | sed 's/"//g' | grep "Meeting Update Reminders" | awk -F " : " '{print $NF}') == "false" ]]; then
        echo "User Made changes Meeting Update Reminders"
        flag=1
    fi
fi

if [[ "${flag}" -gt 0 ]]; then
    AgreeScreen=$(dialog \
        --commandfile "${CommandFile}" \
        --hidetimerbar \
        --ontop \
        --moveable \
        --width 800 \
        --bannerimage "${brandHeader}" \
        --bannertitle "WARNING" \
        --icon "${brandIcon}" \
        --titlefont "shadow=1" \
        --message "You have made changes from the default PUMA Configuration.  \n  \nThis may result in you missing notifications and apps force quiting unexpectedly.  \n  \nThese changes will be logged to your account for support." \
        --button1text "Apply Changes" \
        --button2text "Cancel" \
        --messagefont "size=16,colour=#F58220" \
        --checkbox "I Understand and Accept the Consequences",enableButton1 \
        --button1disabled \
        --timer 600 \
        --quitkey X)

    # Creates the xml plist file
    [[ -f "${pumaUserPrefs}" ]] || plutil -create xml1 "${pumaUserPrefs}"
fi

if [[ $(echo "${AgreeScreen}" | sed 's/"//g' | grep "I Understand and Accept the Consequences" | awk -F " : " '{print $NF}') == "true" ]]; then
    if [[ $(echo "${dialogReturned}" | sed 's/"//g' | grep "Use Notification Center" | awk -F " : " '{print $NF}') == "true" ]]; then
        echo "User Made changes Use Notification Center"
        plutil -replace "useNotificationCenter" -bool true "${pumaUserPrefs}"
    fi
    if [[ $(echo "${dialogReturned}" | sed 's/"//g' | grep "Critical Updates Override Meeting Call Detections" | awk -F " : " '{print $NF}') == "true" ]]; then
        echo "User Made changes Critical Overrides Meeting Call Detections"
        plutil -replace "criticalOverrideMeetingDetection" -bool true "${pumaUserPrefs}"
    fi
    if [[ $(echo "${dialogReturned}" | sed 's/"//g' | grep "Meeting Update Reminders" | awk -F " : " '{print $NF}') == "false" ]]; then
        echo "User Made changes Meeting Update Reminders"
        plutil -replace "meetingReminders" -bool false "${pumaUserPrefs}"
    fi

fi