#!/bin/bash

# Run away from anything even a little scary
set -o nounset  # Exit if a variable is not set
set -o errexit  # Exit for any command failure

# Text color escape codes (please note \033 == \e but OSX doesn't respect the \e)
blue_text='\033[94m'
red_text='\033[31m'
default_text='\033[39m'

# xtrace uses a Sony PS4 for more info
PS4="$blue_text""${0}:${LINENO}: ""$default_text"

########## Dependency Check ##########
if ! docker compose version >/dev/null 2>/dev/null; then
  echo -e "$red_text""docker compose v2 not found! please install docker compose!""$default_text"
  exit 1
fi

dockerDetachedMode="-d"

# Set current directory to the script's directory
this_file_directory=$(dirname "$0")
cd "$this_file_directory"

# Source the .env file to get version variables
if [ -f dlc-env/.env ]; then
  export $(grep -v '^#' dlc-env/.env | xargs)
else
  echo -e "$red_text""dlc-env/.env file not found! Please create the file with the necessary version information.""$default_text"
  exit 1
fi

# Check if the first argument is "stop"
if [ $# -gt 0 ]; then
  if [ "$1" = "stop" ]; then
    echo -e "$blue_text""Stopping Docker Compose in root directory""$default_text"
    docker compose stop

    echo -e "$blue_text""Stopping Docker services in dlc-airbyte directory""$default_text"
    cd dlc-airbyte
    docker compose stop
    cd - # Go back to the previous directory
    exit 0
  fi
fi


########## Start Docker ##########

echo
echo -e "$blue_text""Starting Docker Compose""$default_text"

docker compose up $dockerDetachedMode

# $? is the exit code of the last command. So here: docker compose up
if test $? -ne 0; then
  echo -e "$red_text""Docker compose failed. If you are seeing container conflicts""$default_text"
  echo -e "$red_text""please consider removing old containers""$default_text"
else
  # Check if the "ab" argument is provided for Airbyte
  if [ $# -gt 0 ] && [ "$1" = "ab" ]; then
    echo -e "$blue_text""Running the Airbyte platform script with flag""$default_text"
    cd dlc-airbyte
    ./run-ab-platform.sh -b
    cd - # Go back to the previous directory
  else
    echo -e "$blue_text""No 'ab' argument provided, skipping Airbyte script execution""$default_text"
  fi
fi
