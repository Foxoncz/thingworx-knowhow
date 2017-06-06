# To make current directory value of THINGWORX_PLATFORM_SETTING, copy this script to desired directory and Run it as Administrator.

# Set variables.
$NAME = "THINGWORX_PLATFORM_SETTINGS"
$VALUE = pwd


Write-Host "==== Trying to set environment variable: ===="
Write-Host "$NAME = $VALUE"

Try {
    [Environment]::SetEnvironmentVariable($NAME, $VALUE, "Machine")
    Write-Host "==== Success, system environment variable was correctly set! ===="
} Catch {
    Write-Warning "Please try again, and run this script as Administrator."
}
Pause