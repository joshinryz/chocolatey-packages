### Author: Joshua Robinett 
### Email:  josh.robinett@gmail.com            
### Github: @jshinryz

# PLEASE USE THE CONFIG FILE TO SET OPTIONS.  RARELY SHOULD ANYTHING NEED TO CHANGE IN THIS FILE

########## PARAM TAKE IN OUR PACKAGE VARIABLE FROM MAIN SCRIPT TO UPDATE
param(
    $repoPackage
)

# This is the include file for all base functions and the base script used. 
try {
    . .\lib\package_class.ps1
    . .\lib\base_CustomInstall.ps1 
    }
catch { Write-Warning "Unable to find include files in $(get-location). Returning False" ; return $false}

#If you wish to override the default behaviour of the main script execution, override the function below.
#function defaultScript($repoPackage) {}
#TESTING:
#$repoPackage = [packageType]::new()
#$repoPackage.id = "package-name"

defaultScript($repoPackage)

return $repoPackage
