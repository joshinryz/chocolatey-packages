### updateFromRepo.ps1
### Author: Joshua Robinett 
### Email:  josh.robinett@gmail.com            
### Github: @jshinryz

## This is an example script we use to call package checks and push those changes to our internal repo

# Include packageType

try {. .\lib\package_class.ps1 }
catch { Write-Error "Failed to import package class .\lib\package_class.ps1 - Exiting"; exit 100}

# THIS SECTION NEEDS TO BE CONFIGURED #
#########################################################
# Web addresses used in script:
$baseURL = "https://inernal-artifactory-server.domain.local"
$repoURL = "$baseURL/api/nuget/v3/chocolatey-internal"
$repoSource = "$baseURL/api/nuget/chocolatey-internal"
$onlineRepo = "https://chocolatey.org/api/v2/"

$apiKey = "API Key that you would use with choco push"  # Example for artifactory: "username:rasjdkfhalskdjhalskjdakljsdfhalsdfh"

# File Paths
$chocoBase = "c:\git\choco-packages"
$chocoPackages =  "$chocoBase\auto-packages"
$customPackageBase =  "$chocoBase\custom-packages"
$customScript = "customInstall.ps1"

# Email config
$emailServer = "smtpserver.domain.local"
$recipients  = "youremail@domain.local"
$fromAddress = (hostname) + "@domain.local"
#########################################################


# Arrays we use to store packages found.
$packages = @()  # found packages searching artifactory

$outdatedPackages = @() # packages that need to be updated
$currentPackages = @()  # packages that are already up to date
$missingPackages = @()  # packages in artifacotry but not online.


#### Sanity Check TODO
# check access to choco
# verify access to artifactory
# check for internal access to public repo
# check access to docker

#SANITY CHECK ON DIRECTORIES - Create if they dont exist.
if (-not (Test-Path $chocoBase) ){ New-Item $chocoBase -Type Directory |out-null}
if (-not (Test-Path $chocoPackages) ){ New-Item $chocoPackages -Type Directory |out-null} 
if (-not (Test-Path $customPackageBase) ){ New-Item $customPackageBase -Type Directory |out-null} 


### Sanity Check on Repo ##
# TODO check our source and compare to external listed #


# Set out current running directory
Set-Location -Path $chocoBase

# Clean the auto-packages folder:
Remove-Item -Recurse -force $chocoPackages |out-null
New-Item -ItemType Directory -Force -Path $chocoPackages |out-null


# Here we try to connect our our internal repo. Catch if it fails and nicely exit.
try 
{
    $packageList = choco list -r -s $repoSource
    #$packageList = (Invoke-RestMethod -Uri "$repoURL/query").data
}
catch
{
    Write-Warning "Error connecting to $baseURL - Script is exiting."
    #TODO : Include HTTP error code in return message.
    exit
}


$customPackageNames = @()
$childFolders = Get-ChildItem $customPackageBase
foreach ($folder in $childFolders){
    # For each custom package folder found, check if a custom install is defined.
    if (test-path $customPackageBase\$folder\$customScript){
        $customPackageNames += $folder.Name
    }
    
}

$packages = @()

foreach ($package in $packageList) {
    $package_id = $package.split("|") |select -First 1
    $package_vr = $package.split("|") |select -Last 1

    $myPackage = [packageType]::new()
    $myPackage.id = $package_id
    $myPackage.version = $package_vr
    $myPackage.Outdated = $false
    $myPackage.NewVersion = ""
    $myPackage.Updated = $false
    $myPackage.StatusMessage = "None"


    #$myPackage | Add-Member -Type NoteProperty -Name id -Value $package.id
    #$myPackage | Add-Member -Type NoteProperty -Name version -Value  $package.version
    $packages += $myPackage  
}
#### TODO- Wrap into function or multiprocessing step - too slow ####
#####################################################################

foreach ($package in $packages){
    $currentVersion = [System.Version]$package.version
    $packageName = $package.id
    
    # check if there is an overriding custom package script.
    if($customPackageNames -contains $packageName)
    {
        #Skip normal download for custom packages.
        write-host "Running custom script for  $packageName" -ForegroundColor Blue
        $scriptPath = "$customPackageBase\$packageName\$customScript"
        $result = [packageType]::new()
        $result = & $scriptPath $package   
        $package.StatusMessage = $result.StatusMessage
        $package.Updated = $result.Updated
        $package.NewVersion = $result.NewVersion
        $package.Outdated = $result.Outdated

        if ($package.Outdated -and $package.Updated) {
            $outdatedPackages += $package
            Write-Host "Newer Version of : $packageName . Old Version: $currentVersion  , newer Version: $($package.NewVersion)" -ForegroundColor Green
        }
        else{
            Write-Host "Package is already up to date $packageName" -ForegroundColor Yellow 
        }
        
    }
    else {
        # Search the online repo for out package name - use strict matching.  
        $searchOnline = choco search -r -e $package.id -s $onlineRepo
        
        #if We find results - run if
        if ($searchOnline) {
            
            try { $onlineVersion = [System.Version] $searchOnline.Split("|")[1] }
            catch { write-Host "Error converting $($searchOnline.Split("|")[1]) to a versions." -ForegroundColor Red
                    $onlineVersion = $null}

            if($onlineVersion -gt $currentVersion -and $onlineVersion)
            {

                Write-Host "Newer Version of : $packageName . Old Version: $currentVersion  , online Version: $onlineVersion" -ForegroundColor Green
                $package.Outdated = $true
                $package.NewVersion = $onlineVersion
                $outdatedPackages += $package
            }
            else 
            { 
                Write-Host "Package is already up to date $packageName" -ForegroundColor Yellow 
                $currentPackages += $package
                $package.Outdated = $false
            }
        }
        else 
        {
            Write-Warning "Package not found: $packageName"
            $missingPackages += $package
        }
    }

}
#####################################################################
<#
if($outdatedPackages)
{
    #Prep our docker image
    # update git repo ??
    docker build $dockerBuild -t "choco-test"
    $image = docker ps -q -f "ancestor=choco-test"    
    if (!$image) {
        docker run -t -d choco-test
        $image = docker ps -q -f "ancestor=choco-test"    
    }
    
}

if($image)
{
    write-host "Docker image is running: $image"
    docker exec $image powershell -command  New-Item $dockerFolder -ItemType Directory -Force
    $TestDocker = $true
}
#>

if(!$outdatedPackages)
{
    Write-Warning " No new packages found - Exiting Script."
    #exit
}
else
{
    foreach ($InstallPackage in $outdatedPackages)
    {
        #Check to see if need to skip *.install packages due to redundancy in virtual package
        if ($InstallPackage.id -like "*.install" -and $outdatedPackages.id -contains ($InstallPackage.id.Replace('.install','')))
        {
            Write-Warning ($InstallPackage.id + ' skipping due to existing virtual package')  
            Continue
        }
        
        if ($InstallPackage.Updated -eq $false)
        {
            
            
                    
            #Download and internalize the package
            write-host "Downloading $($InstallPackage.id) ..."
            choco download $InstallPackage.id -r --internalize --force  --no-progress --out $chocoPackages  |out-null
            
            if ($LASTEXITCODE -ne 0)
            {
                Write-Warning ($InstallPackage.id + ' internalize failed')
                $Failure.Add($InstallPackage.id) | Out-Null
                $packages.where({$_.id -eq $InstallPackage.id}).StatusMessage = $InstallPackage.id + ' internalize failed'
                Continue
            }
            <#
            write-host "Test docker set to $TestDocker"

            if ($TestDocker) {
                # Launch docker and test install!!!
                write-Output ("Docker $image - Upgrading " + $InstallPackage.id)
                $localPackage = Get-ChildItem -Path $chocoPackages | Where-Object {$_.Extension -eq '.nupkg' -AND $_.BaseName -like $InstallPackage.id+"*" }
                if(!$localPackage) { $LASTEXITCODE = 1 }
                else {          
                    docker cp $localPackage.FullName "$image`:$dockerFolder"
                    docker exec $image powershell -command choco upgrade $InstallPackage.id --source=$dockerFolder --no-progress -r -y
                }
            }
            
            
            
            
            # If failure detected in output continue to next package
            if ( ($LASTEXITCODE -ne 0) -AND ($LASTEXITCODE -ne 3010) -AND (!$TestDocker))
            {
                Write-Warning ($InstallPackage + ' install failed')
                $Failure.Add($InstallPackage) | Out-Null
                Continue
            }
            else
            {
            #>
        }

        $localPackages = Get-ChildItem -Path $chocoPackages | Where-Object {$_.Extension -eq '.nupkg' -AND $_.BaseName -like $InstallPackage.id+"*" } 
        $localPackages | ForEach-Object {             
            choco push $_.Fullname --source=$repoURL --api-key="$apiKey" --force
            if ($LASTEXITCODE -ne 0)
                {
                    Write-Warning ($InstallPackage.id + ' push to artifactory failed')
                    $Failure.Add($InstallPackage.id) | Out-Null
                    $packages | ForEach-Object {
                        if ($_.id -eq $InstallPackage.id)
                        {
                            $_.StatusMessage = $InstallPackage.id + '  push to artifactory FAILED'
                            $_.Updated = $false
                        }
                    }
                }
            else
                {
                    $packages | ForEach-Object {
                        if ($_.id -eq $InstallPackage.id)
                        {
                            $_.StatusMessage = $InstallPackage.id + '  push to artifactory SUCCESS'
                            $_.Updated = $true
                        }
                    }
                }
        }
        
        
      
    #finish loop on outdatePackage list
    }

##########################################################################################################
#
#                          HTML EMAIL SETUP
#########################################################################################################

$htmlOutput = "<html>
                <head>
                    <style>
                        body{ font-family:Verdana, Arial, Helvetica, sans-serif;}
                        #header{background-color:#d6d6d6; font-size:10pt; color:#3e3e3e;}
                        .small{font-size:8pt;}
                        #down{background-color:#FF5555; color:#000;font-weight:bold;font-size:8pt; text-align:center; vertical-align:center;}
                        #red{background-color:#FF5555; color:#000;font-weight:bold;font-size:8pt; text-align:center; vertical-align:center;}
                        #up{background-color:#9ed515; color:#000;font-weight:bold; font-size:8pt; text-align:center; vertical-align:center;}
                        #green{background-color:#9ed515; color:#000;font-weight:bold; font-size:8pt; text-align:center; vertical-align:center;}
                        #critical{background-color:#FF5555; color:#000; font-weight:bold;font-size:8pt;text-align:center; vertical-align:center;}
                        #warning{background-color:#FFDB58; color:#000;font-weight:bold; font-size:8pt; text-align:center; vertical-align:center;}
                        #criticalnonbold{background-color:#FF5555; color:#000; font-size:8pt;text-align:center; vertical-align:center;}
                        #warningnonbold{background-color:#FFDB58; color:#000;font-size:8pt; text-align:center; vertical-align:center;}
                        #unknown{background-color:#eaeaea; color:#000; font-weight:bold;font-size:8pt;text-align:center; vertical-align:center;}
                        #row{background-color:#eaeaea;}
                        table{border-style:solid; border-color:#000; border-width:1px;}
                    </style>
                </head>
                <body>
                <table>
                <tr id=`"header`"><th colspan=`"4`">Chocolatey Package List</th></tr>
                <tr id=`"header`"><th>Package Name</th><th>Version</th><th>New Version</th><th>Status Message</th></tr>`n"
                
               
$packages | Sort-Object | ForEach-Object {
    $htmlOutput += "<tr class=`"small`" id=`"row`"><td>" + $_.id + "</td>"
    if ($_.Outdated) {
        $htmlOutput += "<td id=`"red`">" + $_.version + "</td>"
        
        if ($_.Updated){ $htmlOutput += "<td id=`"green`">" + $_.NewVersion + "</td>" }        
        else { $htmlOutput += "<td id=`"red`">" + $_.NewVersion + "</td>" }
        
        $htmlOutput += "<td>" + $_.StatusMessage + "</td></tr>`n"
    }

    else {
        $htmlOutput += "<td id=`"green`">" + $_.version + "</td><td>" + $_.NewVersion + "</td><td>" + $_.StatusMessage+ "</td></tr>`n"
    }
}

$htmlOutput += "</table></body></html>"


##########################################################################################################
#
#                          Send Email
#########################################################################################################



$message = new-object System.Net.Mail.MailMessage 
$message.From = $fromAddress
$message.To.Add($recipients)
$message.IsBodyHtml = $true
$message.Subject = "Chocolatey - New Package Updates!"
$message.Body = $htmlOutput
$smtp = new-object Net.Mail.SmtpClient($emailServer) 
$smtp.Send($message) 



 }