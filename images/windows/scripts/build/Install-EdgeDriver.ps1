################################################################################
##  File:  Install-EdgeDriver.ps1
##  Desc:  Install Edge WebDriver and configure Microsoft Edge
################################################################################

# Disable Edge auto-updates
Rename-Item -Path "C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" -NewName "Disabled_MicrosoftEdgeUpdate.exe" -ErrorAction Stop

Write-Host "Get the Microsoft Edge WebDriver version..."
$edgeBinaryPath = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe").'(default)'
[version] $edgeVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($edgeBinaryPath).ProductVersion

$edgeDriverPath = "$($env:SystemDrive)\SeleniumWebDrivers\EdgeDriver"
if (-not (Test-Path -Path $edgeDriverPath)) {
    New-Item -Path $edgeDriverPath -ItemType Directory -Force
}

$versionInfoUrl = "https://msedgedriver.microsoft.com/LATEST_RELEASE_$($edgeVersion.Major)_WINDOWS"
$versionInfoFile = Invoke-DownloadWithRetry -Url $versionInfoUrl -Path "$edgeDriverPath\versioninfo.txt"
$latestVersion = Get-Content -Path $versionInfoFile

Write-Host "Download Microsoft Edge WebDriver..."
$downloadUrl = "https://msedgedriver.microsoft.com/$latestVersion/edgedriver_win64.zip"
$archivePath = Invoke-DownloadWithRetry $downloadUrl

Write-Host "Expand Microsoft Edge WebDriver archive..."
Expand-7ZipArchive -Path $archivePath -DestinationPath $edgeDriverPath

#Validate the EdgeDriver signature
Test-FileSignature -Path "$edgeDriverPath\msedgedriver.exe" -ExpectedSubject $(Get-MicrosoftPublisher)

Write-Host "Setting the environment variables..."
[Environment]::SetEnvironmentVariable("EdgeWebDriver", $EdgeDriverPath, "Machine")
Add-MachinePathItem "$edgeDriverPath\"

Invoke-PesterTests -TestFile "Browsers" -TestName "Edge"
