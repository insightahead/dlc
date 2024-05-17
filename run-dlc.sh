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

# Function to check if a Docker image exists locally
image_exists() {
  docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "$1"
}

# Function to download and extract images from GitHub release
download_and_extract_images() {
  if [ -z "${DLC_RELEASE_TAG}" ]; then
    echo -e "$red_text""DLC_RELEASE_TAG environment variable is not set!""$default_text"
    exit 1
  fi

  local url="https://github.com/insightahead/dlc/releases/download/${DLC_RELEASE_TAG}/dlc-images.zip"

  echo "Downloading images from GitHub release..."

  curl -L -o dlc-images.zip "$url"

  echo "Extracting images..."
  unzip dlc-images.zip -d dlc-images-temp
  rm dlc-images.zip

 # Create dlc-images directory if it doesn't exist
  mkdir -p dlc-images
  # Move files from nested directory to dlc-images
  mv dlc-images-temp/* dlc-images/
  rmdir dlc-images-temp/
}

# Function to load Docker images from tar files
load_images_from_tar() {
  IMAGE_DIR="dlc-images"

  # Check if the directory exists
  if [ ! -d "$IMAGE_DIR" ]; then
    echo "Directory $IMAGE_DIR does not exist."
    exit 1
  fi

  # Iterate over all .tar files in the directory and load them
  for image_tar in "$IMAGE_DIR"/*.tar; do
    if [ -f "$image_tar" ]; then
      echo "Loading Docker image from $image_tar..."
      docker load -i "$image_tar"
      if [ $? -eq 0 ]; then
        echo "Successfully loaded $image_tar"
      else
        echo "Failed to load $image_tar"
      fi
    else
      echo "No .tar files found in $IMAGE_DIR."
    fi
  done

  echo "All Docker images loaded."
}

# Check if the dlc-images directory exists, if not download and extract images
if [ ! -d "dlc-images" ]; then
  echo -e "$blue_text""dlc-images directory not found. Downloading and extracting images...""$default_text"
  download_and_extract_images
fi

# Check if the specific images exist locally
REQUIRED_IMAGES=(
  "ghcr.io/insightahead/dlc-ui:${DLC_RELEASE_TAG}"
  "ghcr.io/insightahead/dlc-data-generator:${DLC_RELEASE_TAG}"
  "ghcr.io/insightahead/dlc-data-loader:${DLC_RELEASE_TAG}"
)

missing_images=0

for image in "${REQUIRED_IMAGES[@]}"; do
  if ! image_exists "$image"; then
    if [[ "$image" == ghcr.io/insightahead/* ]]; then
      echo -e "$red_text""Image $image not found locally and needs to be installed from tar files.""$default_text"
      missing_images=1
    else
      echo -e "$red_text""Image $image not found locally. Attempting to pull from Docker Hub...""$default_text"
      docker pull "$image"
    fi
  fi
done

# If any images from ghcr.io are missing, load them from tar files
if [ $missing_images -ne 0 ]; then
  echo -e "$blue_text""Loading missing images from tar files...""$default_text"
  load_images_from_tar
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
