Import-Module "$PSScriptRoot/../helpers/Common.Helpers.psm1"
Import-Module "$PSScriptRoot/Helpers.psm1" -DisableNameChecking
Import-Module "$PSScriptRoot/../software-report/SoftwareReport.Android.psm1" -DisableNameChecking

$os = Get-OSVersion

Describe "Android" {
    $androidSdkManagerPackages = Get-AndroidPackages
    [int]$platformMinVersion = (Get-ToolsetContent).android.platform_min_version
    [version]$buildToolsMinVersion = (Get-ToolsetContent).android.build_tools_min_version
    [array]$ndkVersions = (Get-ToolsetContent).android.ndk.versions
    $ndkFullVersions = $ndkVersions | ForEach-Object { Get-ChildItem "$env:ANDROID_HOME/ndk/${_}.*" -Name | Select-Object -Last 1 } | ForEach-Object { "ndk/${_}" }
    # Platforms starting with a letter are the preview versions, which is not installed on the image
    $platformVersionsList = ($androidSdkManagerPackages | Where-Object { "$_".StartsWith("platforms;") }) -replace 'platforms;android-', '' | Where-Object { $_ -match "^\d" } | Sort-Object -Unique
    $platformsInstalled = $platformVersionsList | Where-Object { [int]($_.Split("-")[0]) -ge $platformMinVersion } | ForEach-Object { "platforms/android-${_}" }

    $buildToolsList = ($androidSdkManagerPackages | Where-Object { "$_".StartsWith("build-tools;") }) -replace 'build-tools;', ''
    $buildTools = $buildToolsList | Where-Object { $_ -match "\d+(\.\d+){2,}$" } | Where-Object { [version]$_ -ge $buildToolsMinVersion } | Sort-Object -Unique |
        ForEach-Object { "build-tools/${_}" }

    $androidPackages = @(
        "tools",
        "platform-tools",
        "cmake",
        $platformsInstalled,
        $buildTools,
        $ndkFullVersions,
        ((Get-ToolsetContent).android.extras | ForEach-Object { "extras/${_}" }),
        ((Get-ToolsetContent).android.addons | ForEach-Object { "add-ons/${_}" }),
        ((Get-ToolsetContent).android.additional_tools)
    ) | ForEach-Object { $_ }

    # Remove empty strings from array to avoid possible issues
    $androidPackages = $androidPackages | Where-Object { $_ }

    BeforeAll {
        $ANDROID_SDK_DIR = Join-Path $env:HOME "Library" "Android" "sdk"

        function Confirm-AndroidPackage {
            param (
                [Parameter(Mandatory = $true)]
                [string] $PackageName
            )

            # Convert 'm2repository;com;android;support;constraint;constraint-layout-solver;1.0.0-beta1' ->
            #         'm2repository/com/android/support/constraint/constraint-layout-solver/1.0.0-beta1'
            $PackageName = $PackageName.Replace(";", "/")
            $targetPath = Join-Path $ANDROID_SDK_DIR $PackageName
            $targetPath | Should -Exist
        }
    }

    Context "SDKManagers" {
        $testCases = @(
            @{
                PackageName = "Command-line tools"
                Sdkmanager  = "$env:ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
            }
        )

        It "Sdkmanager from <PackageName> is available" -TestCases $testCases {
            "$Sdkmanager --version" | Should -ReturnZeroExitCode
        }
    }

    Context "Packages" {
        $testCases = $androidPackages | ForEach-Object { @{ PackageName = $_ } }

        It "<PackageName>" -TestCases $testCases {
            param ([string] $PackageName)
            Confirm-AndroidPackage $PackageName
        }
    }
}
