param(
    [ValidateSet("major", "minor", "patch", "build")]
    [string]$part = "patch"
)

$yamlPath = "pubspec.yaml"
$yaml = Get-Content $yamlPath

# Extract version line and numbers
$versionLine = $yaml | Where-Object { $_ -match "^version:" }
if (-not $versionLine) { Write-Error "No version line found!"; exit 1 }
if ($versionLine -match "([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)") {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
    $build = [int]$matches[4]
} else {
    Write-Error "Could not parse version!"; exit 1
}

switch ($part) {
    "major" { $major++; $minor=0; $patch=0; $build=1 }
    "minor" { $minor++; $patch=0; $build=1 }
    "patch" { $patch++; $build=1 }
    "build" { $build++ }
}

$newVersion = "$major.$minor.$patch+$build"
$yaml = $yaml -replace "^version:.*", "version: $newVersion"
Set-Content $yamlPath $yaml

git add $yamlPath
git commit -m "Bump version to $newVersion"
git tag "v$newVersion"
git push origin main --tags

Write-Host "Version bumped to $newVersion and tag v$newVersion created and pushed."
