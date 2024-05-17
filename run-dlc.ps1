# Run away from anything even a little scary
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Text color escape codes
$blue_text = "`e[94m"
$red_text = "`e[31m"
$default_text = "`e[39m"

# xtrace uses a Sony PS4 for more info
$PS4 = "$blue_text`$($MyInvocation.MyCommand.Name):$($MyInvocation.ScriptLineNumber): $default_text"

########## Dependency Check ##########
if (-not (Get-Command "docker-compose" -ErrorAction SilentlyContinue)) {
    Write-Host "$red_text`docker-compose v2 not found! Please install docker-compose!$default_text"
    exit 1
}

$dockerDetachedMode = "-d"

# Set current directory to the script's directory
$this_file_directory = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $this_file_directory

# Source the .env file to get version variables
$env_file = "dlc-env/.env"
if (Test-Path $env_file) {
    Get-Content $env_file | ForEach-Object {
        if ($_ -notmatch '^\s*#') {
            $key, $value = $_ -split '=', 2
            $env:$key = $value
        }
    }
} else {
    Write-Host "$red_text`dlc-env/.env file not found! Please create the file with the necessary version information.$default_text"
    exit 1
}

# Check if the first argument is "stop"
if ($args.Length -gt 0 -and $args[0] -eq "stop") {
    Write-Host "$blue_text`Stopping Docker Compose in root directory$default_text"
    docker-compose stop

    Write-Host "$blue_text`Stopping Docker services in dlc-airbyte directory$default_text"
    Set-Location dlc-airbyte
    docker-compose stop
    Pop-Location
    exit 0
}

# Function to check if a Docker image exists locally
function ImageExists {
    param (
        [string]$image
    )
    docker images --format '{{.Repository}}:{{.Tag}}' | Select-String -Pattern $image -Quiet
}

# Function to download and extract images from GitHub release
function DownloadAndExtractImages {
    if (-not $env:DLC_RELEASE_TAG) {
        Write-Host "$red_text`DLC_RELEASE_TAG environment variable is not set!$default_text"
        exit 1
    }

    $url = "https://github.com/insightahead/dlc/releases/download/$($env:DLC_RELEASE_TAG)/dlc-images.zip"

    Write-Host "Downloading images from GitHub release..."
    Invoke-WebRequest -Uri $url -OutFile dlc-images.zip

    Write-Host "Extracting images..."
    Expand-Archive -Path dlc-images.zip -DestinationPath dlc-images-temp
    Remove-Item dlc-images.zip

    # Create dlc-images directory if it doesn't exist
    if (-not (Test-Path -Path dlc-images)) {
        New-Item -ItemType Directory -Path dlc-images
    }

    # Move files from nested directory to dlc-images
    Move-Item -Path dlc-images-temp\* -Destination dlc-images
    Remove-Item dlc-images-temp -Recurse
}

# Function to load Docker images from tar files
function LoadImagesFromTar {
    $IMAGE_DIR = "dlc-images"

    # Check if the directory exists
    if (-not (Test-Path -Path $IMAGE_DIR)) {
        Write-Host "Directory $IMAGE_DIR does not exist."
        exit 1
    }

    # Iterate over all .tar files in the directory and load them
    Get-ChildItem -Path "$IMAGE_DIR\*.tar" | ForEach-Object {
        Write-Host "Loading Docker image from $($_.FullName)..."
        docker load -i $_.FullName
        if ($?) {
            Write-Host "Successfully loaded $($_.Name)"
        } else {
            Write-Host "Failed to load $($_.Name)"
        }
    }

    Write-Host "All Docker images loaded."
}

# Check if the dlc-images directory exists, if not download and extract images
if (-not (Test-Path -Path "dlc-images")) {
    Write-Host "$blue_text`dlc-images directory not found. Downloading and extracting images...$default_text"
    DownloadAndExtractImages
}

# Check if the specific images exist locally
$REQUIRED_IMAGES = @(
    "ghcr.io/insightahead/dlc-ui:$($env:DLC_RELEASE_TAG)",
    "ghcr.io/insightahead/dlc-data-generator:$($env:DLC_RELEASE_TAG)",
    "ghcr.io/insightahead/dlc-data-loader:$($env:DLC_RELEASE_TAG)"
)

$missing_images = 0

foreach ($image in $REQUIRED_IMAGES) {
    if (-not (ImageExists $image)) {
        if ($image -like "ghcr.io/insightahead/*") {
            Write-Host "$red_text`Image $image not found locally and needs to be installed from tar files.$default_text"
            $missing_images++
        } else {
            Write-Host "$red_text`Image $image not found locally. Attempting to pull from Docker Hub...$default_text"
            docker pull $image
        }
    }
}

# If any images from ghcr.io are missing, load them from tar files
if ($missing_images -ne 0) {
    Write-Host "$blue_text`Loading missing images from tar files...$default_text"
    LoadImagesFromTar
}

########## Start Docker ##########

Write-Host ""
Write-Host "$blue_text`Starting Docker Compose$default_text"

docker-compose up $dockerDetachedMode

# Check the exit code of the last command
if ($LASTEXITCODE -ne 0) {
    Write-Host "$red_text`Docker compose failed. If you are seeing container conflicts$default_text"
    Write-Host "$red_text`please consider removing old containers$default_text"
} else {
    # Check if the "ab" argument is provided for Airbyte
    if ($args.Length -gt 0 -and $args[0] -eq "ab") {
        Write-Host "$blue_text`Running the Airbyte platform script with flag$default_text"
        Set-Location dlc-airbyte
        ./run-ab-platform.sh -b
        Pop-Location
    } else {
        Write-Host "$blue_text`No 'ab' argument provided, skipping Airbyte script execution$default_text"
    }
}
