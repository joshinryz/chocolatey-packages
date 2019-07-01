### Author: Joshua Robinett 
### Email:  josh.robinett@gmail.com            
### Github: @jshinryz

# This is the include file for all base functions and the base script used. 
try {
    . .\lib\package_class.ps1
    . .\lib\base_CustomInstall.ps1 
    }
catch { Write-Warning "Unable to find include files in $(get-location). Returning False" ; return $false}


# setup folders for paths. We get the package from the function that calls this script. Defined there.
#### TODO - START HERE
$downloadPath = ".\custom-packages\download\" + $package.id + "\files\"
$tempPath = $ENV:TEMP + "\Office365\"
$customPath = customPath($package)
$networkPath = "\\network\path"



# Ensure we can run everything
Set-ExecutionPolicy Bypass -Scope Process -Force

#$licenseLocation = "$networkPath\license\chocolatey.license.xml"
$packagingFolder = "$env:SystemDrive\choco-setup\packaging"
$packagesFolder = "$env:SystemDrive\choco-setup\packages"
$packageId = "chocolatey-license"
$licensePackageFolder = "$packagingFolder\$packageId"
$licensePackageNuspec = "$licensePackageFolder\$packageId.nuspec"

# Ensure the packaging folder exists
#Write-Output "Generating package/packaging folders at '$packagingFolder'"
#New-Item $packagingFolder -ItemType Directory -Force | Out-Null
#New-Item $packagesFolder -ItemType Directory -Force | Out-Null

# Create a new package
#Write-Output "Creating package named  '$packageId'"
New-Item $licensePackageFolder -ItemType Directory -Force | Out-Null
New-Item "$licensePackageFolder\tools" -ItemType Directory -Force | Out-Null

# Set the installation script
Write-Output "Setting install and uninstall scripts..."
@"
`$ErrorActionPreference = 'Stop'
`$toolsDir              = "`$(Split-Path -parent `$MyInvocation.MyCommand.Definition)"
`$licenseFile           = "`$toolsDir\chocolatey.license.xml"

New-Item "`$env:ChocolateyInstall\license" -ItemType Directory -Force
Copy-Item -Path `$licenseFile  -Destination `$env:ChocolateyInstall\license\chocolatey.license.xml -Force
Write-Output "The license has been installed."
"@ | Out-File -FilePath "$licensePackageFolder\tools\chocolateyInstall.ps1" -Encoding UTF8 -Force

# Set the uninstall script
@"
Remove-Item -Path "`$env:ChocolateyInstall\license\chocolatey.license.xml" -Force
Write-Output "The license has been removed."
"@ | Out-File -FilePath "$licensePackageFolder\tools\chocolateyUninstall.ps1" -Encoding UTF8 -Force

# Copy the license to the package directory
Write-Output "Copying license to package from '$licenseLocation'..."
Copy-Item -Path $licenseLocation  -Destination "$licensePackageFolder\tools\chocolatey.license.xml" -Force

# Set the nuspec
Write-Output "Setting nuspec..."
@"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
  <metadata>
    <id>chocolatey-license</id>
    <version>$version</version>
    <!--<owners>__REPLACE_YOUR_NAME__</owners>-->
    <title>Chocolatey License</title>
    <authors>__REPLACE_AUTHORS_OF_SOFTWARE_COMMA_SEPARATED__</authors>
    <tags>chocolatey license</tags>
    <summary>Installs the Chocolatey commercial license file.</summary>
    <description>This package ensures installation of the Chocolatey commercial license file.

This should be installed internally prior to installing other packages, directly after Chocolatey is installed and prior to installing `chocolatey.extension` and `chocolatey-agent`.

The order for scripting is this:
* chocolatey
* chocolatey-license
* chocolatey.extension
* chocolatey-agent

If items are installed in any other order, it could have strange effects or fail.
  </description>
    <!-- <releaseNotes>__REPLACE_OR_REMOVE__MarkDown_Okay</releaseNotes> -->
  </metadata>
  <files>
    <file src="tools\**" target="tools" />
  </files>
</package>
"@  | Out-File -FilePath "$licensePackageNuspec" -Encoding UTF8 -Force

# Package up everything
Write-Output "Creating a package"
choco pack $licensePackageNuspec --output-directory="$packagesFolder"

Write-Output "Package has been created and is ready at $packagesFolder"

return $statusMessage