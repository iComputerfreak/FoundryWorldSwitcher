#!/bin/sh

set -e

TARGET="$1"

if [[ -z "$TARGET" ]]; then
	echo "Please specify the target directory."
	exit 1
fi

cp BOT_TOKEN "$1/BOT_TOKEN"
cp PTERODACTYL_API_KEY "$1/PTERODACTYL_API_KEY"
cp botConfig.json "$1/data/botConfig.json"