# Stop on any error
$ErrorActionPreference = "Stop"

# Text color escape codes for PowerShell (simplified)
$blue_text = "[94m"
$red_text = "[31m"
$default_text = "[39m"

########## Dependency Check ##########
# Check if Docker Compose V2 is installed
try {
    docker compose version > $null 2>&1
} catch {
    Write-Host "$red_text Docker Compose v2 not found! Please install Docker Compose! $default_text"
    exit 1
}

$dockerDetachedMode = "-d"

# Set current directory to the script's directory
$this_file_directory = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $this_file_directory

# Source the .env file to get version variables
if (Test-Path dlc-env/.env) {
    Get-Content dlc-env/.env | ForEach-Object {
        if ($_ -match "^\s*#") { return }  # Skip commented lines
        if ($_ -match "^\s*$") { return }  # Skip empty lines
        $name, $value = $_ -split '=', 2
        $name = $name.Trim()
        $value = $value.Trim()
        [Environment]::SetEnvironmentVariable($name, $value)
    }
} else {
    Write-Host "$red_text dlc-env/.env file not found! Please create the file with the necessary version information. $default_text"
    exit 1
}

# Check if the first argument is "stop"
if ($args.Length -gt 0 -and $args[0] -eq "stop") {
    Write-Host "$blue_text Stopping Docker Compose in root directory $default_text"
    docker compose stop

    Write-Host "$blue_text Stopping Docker services in dlc-airbyte directory $default_text"
    Set-Location dlc-airbyte
    docker compose stop
    Set-Location -  # Go back to the previous directory
    exit 0
}

# Function to check if a Docker image exists locally
function image_exists {
    param (
        [string]$image
    )
    docker images --format '{{.Repository}}:{{.Tag}}' | Select-String -Quiet "$image"
    return $?
}

# Function to load Docker images from tar files
function load_images_from_tar {
    $IMAGE_DIR = "dlc-images"

    # Check if the directory exists
    if (-not (Test-Path $IMAGE_DIR)) {
        Write-Host "Directory $IMAGE_DIR does not exist."
        exit 1
    }

    # Iterate over all .tar files in the directory and load them
    Get-ChildItem -Path $IMAGE_DIR -Filter *.tar | ForEach-Object {
        $image_tar = $_.FullName
        Write-Host "Loading Docker image from $image_tar..."
        docker load -i "$image_tar"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully loaded $image_tar"
        } else {
            Write-Host "Failed to load $image_tar"
        }
    }

    Write-Host "All Docker images loaded."
}

# Check if the specific images exist locally
$REQUIRED_IMAGES = @(
    "ghcr.io/insightahead/dlc-ui:$env:DLC_UI_VERSION",
    "ghcr.io/insightahead/dlc-data-generator:$env:DLC_DATA_GENERATOR_VERSION",
    "ghcr.io/insightahead/dlc-data-loader:$env:DLC_DATA_LOADER_VERSION",
    "postgres:$env:POSTGRES_VERSION",
    "dpage/pgadmin4:$env:PGADMIN_VERSION"
)

$missing_images = 0

foreach ($image in $REQUIRED_IMAGES) {
    if (-not (image_exists $image)) {
        if ($image -like "ghcr.io/insightahead/*") {
            Write-Host "$red_text Image $image not found locally and needs to be installed from tar files. $default_text"
            $missing_images = 1
        } else {
            Write-Host "$red_text Image $image not found locally. Attempting to pull from Docker Hub... $default_text"
            docker pull $image
        }
    }
}

# If any images from ghcr.io are missing, load them from tar files
if ($missing_images -ne 0) {
    Write-Host "$blue_text Loading missing images from tar files... $default_text"
    load_images_from_tar
}

########## Start Docker ##########

Write-Host
Write-Host "$blue_text Starting Docker Compose $default_text"

docker compose up $dockerDetachedMode

# $? is the exit code of the last command. So here: docker compose up
if ($LASTEXITCODE -ne 0) {
    Write-Host "$red_text Docker compose failed. If you are seeing container conflicts $default_text"
    Write-Host "$red_text please consider removing old containers $default_text"
} else {
    # Check if the "ab" argument is provided for Airbyte
    if ($args.Length -gt 0 -and $args[0] -eq "ab") {
        Write-Host "$blue_text Running the Airbyte platform script with flag $default_text"
        Set-Location dlc-airbyte
        .\run-ab-platform.sh -b
        Set-Location -  # Go back to the previous directory
    } else {
        Write-Host "$blue_text No 'ab' argument provided, skipping Airbyte script execution $default_text"
    }
}
