# PowerShell script to load keystore.env and build release APK
# Usage: .\build_with_env.ps1

$envFile = "android/app/keystore.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^(.*?)=(.*)$') {
            $name = $matches[1]
            $value = $matches[2]
            [System.Environment]::SetEnvironmentVariable($name, $value)
            ${env:$name} = $value
        }
    }
    Write-Host "Loaded environment variables from $envFile"
} else {
    Write-Host "Environment file $envFile not found."
    exit 1
}

flutter build appbundle
