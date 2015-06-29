on run argv
    set appName to item 1 of argv

    if not application appName is running then
        tell application appName
            activate
        end tell

    else if application appName is frontmost then
        tell application "Finder"
            set visible of process appName to false
        end tell

    else
        tell application "Finder"
            set visible of process appName to true
        end tell
    end if
end run


