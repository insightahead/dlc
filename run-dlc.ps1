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
