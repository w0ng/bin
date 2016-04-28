#!/bin/bash

# imgur script by Bart Nagel <bart@tremby.net>
# version 4
# I release this into the public domain. Do with it what you will.

# Required: curl
#
# Optional: xsel or xclip for automatically putting the URLs on the X selection 
# for easy pasting
#
# Instructions:
# Put it somewhere in your path and maybe rename it:
# 	mv ~/Downloads/imgurbash.sh ~/bin/imgur
# Make it executable:
# 	chmod +x ~/bin/imgur
# Optional, since Alan kindly provided an API key for this script: stick your 
# API key in the top:
# 	vim ~/bin/imgur
# Upload an image:
# 	imgur images/hilarious/manfallingover.jpg
# Upload multiple images:
# 	imgur images/delicious/cake.png images/exciting/bungeejump.jpg
# The URLs will be displayed (and the delete page's URLs will be displayed on 
# stderr). If you have xsel or xclip the URLs will also be put on the X 
# selection, which you can usually paste with a middle click.

# OAuth 2.0 Client ID.
clientid="3d46d46f960fd56"

# function to output usage instructions
function usage {
	echo "Usage: $(basename "$0") <filename> [<filename> [...]]" >&2
	echo "Upload images to imgur and output their new URLs to stdout. Each one's" >&2
	echo "delete page is output to stderr between the view URLs." >&2
	echo "If xsel or xclip is available, the URLs are put on the X selection for" >&2
	echo "easy pasting." >&2
}

# check API key has been entered
if [ -z "$clientid" ]; then
	echo "You first need to edit the script and put your API key in the variable near the top." >&2
	exit 15
fi

# check arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
	exit 0
elif [ $# == 0 ]; then
	echo "No file specified" >&2
	usage
	exit 16
fi

# check curl is available
type curl >/dev/null 2>/dev/null || {
	echo "Couln't find curl, which is required." >&2
	exit 17
}

clip=""
errors=false

# loop through arguments
while [ $# -gt 0 ]; do
	file="$1"
	shift

	# check file exists
	if [ ! -f "$file" ]; then
		echo "file '$file' doesn't exist, skipping" >&2
		errors=true
		continue
	fi

	# upload the image
	# the "Expect: " header is to get around a problem when using this through 
	# the Squid proxy. Not sure if it's a Squid bug or what.
	response=$(curl -H "Authorization: Client-ID $clientid" -H "Expect: " \
        -F "image=@$file" https://api.imgur.com/3/image.xml 2>/dev/null)
	if [ $? -ne 0 ]; then
		echo "Upload failed" >&2
		errors=true
		continue
	elif [ "$(echo "$response" | grep -c "<error_msg>")" -gt 0 ]; then
		echo "Error message from imgur:" >&2
        if [ "$(uname)" = "Linux" ]; then
            # GNU (Linux) sed
            echo "$response" | sed -r 's/.*<error_msg>(.*)<\/error_msg>.*/\1/' >&2
        else
            # BSD (OSX) sed
            echo "$response" | sed -E 's/.*<error_msg>(.*)<\/error_msg>.*/\1/' >&2
        fi
		errors=true
		continue
	fi

	# parse the response and output our stuff
    if [ "$(uname)" = "Linux" ]; then
        # GNU (Linux) sed
        url=$(echo "$response" | sed -r 's/.*<original_image>(.*)<\/original_image>.*/\1/')
        deletehash=$(echo "$response" | sed -r 's/.*<deletehash>(.*)<\/deletehash>.*/\1/')
    else
        # BSD (OSX) sed
        url=$(echo "$response" | sed -E 's/.*<original_image>(.*)<\/original_image>.*/\1/')
        deletehash=$(echo "$response" | sed -E 's/.*<deletedash>(.*)<\/deletedash>.*/\1/')
    fi
	echo "$url"
	echo "Delete page: https://imgur.com/delete/$deletehash" >&2

	# append the URL to a string so we can put them all on the clipboard later
	clip="$clip$url
"
done

# put the URLs on the clipboard if we have xsel or xclip
if [ "$(uname)" = "Linux" ]; then
    if [ -n "$DISPLAY" ]; then
        { type xsel >/dev/null 2>/dev/null && echo -n "$clip" | xsel; } \
            || { type xclip >/dev/null 2>/dev/null && echo -n "$clip" | xclip; } \
            || echo "Haven't copied to the clipboard: no xsel or xclip" >&2
    else
        echo "Haven't copied to the clipboard: no \$DISPLAY" >&2
    fi
elif [ "$(uname)" = "Darwin" ]; then
    { type pbcopy >/dev/null 2>/dev/null && echo -n "$clip" | pbcopy; } \
        || echo "Haven't copied to the clipboard: no pbcopy" >&2
fi

if $errors; then
	exit 1
fi
