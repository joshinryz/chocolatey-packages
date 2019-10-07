### SHARED CODE - DO NOT CHANGE THIS SCRIPT, IT WILL AFFECT ALL CUSTOM PACKAGES ###
### Author: Joshua Robinett 
### Email:  josh.robinett@gmail.com            
### Github: @jshinryz

### Global Settings 
### TODO: Lets get rid of this stuff - recursively search our path - better approach
##  TODO: Move these into an include file (so it can be included elswhere)

$chocoBase = "c:\git\chocolatey-packages"
$chocoPackages =  "$chocoBase\auto-packages"
$chocoCustomFolder =  "$chocoBase\custom-packages"

# Name of script to look for to customize packages.
$customInstallScript = "customInstall.ps1"

function customPath($package){
    
    $packageName = $package.id
    $location = get-location

    # Test paths in order for $customInstallScript
    if (test-path $PSScriptRoot\$customInstallScript){
        $pwd = $PSScriptRoot
    }
    elseif (Test-Path $location\$packageName\$customInstallScript) {
        $pwd = "$(get-location)\$packageName"
    }
    elseif (Test-Path $chocoCustomFolder\$packageName\$customInstallScript){
        $pwd = "$chocoCustomFolder\$packageName"
    }
    else{
        if (test-path $location\$customInstallScript){
            $pwd = Get-Location
        }
        else { 
            Write-Warning "Can not determine path we should be using from $pwd."
            $pwd =  $null

        }
    }
    return $pwd
}


function checkForSilentArgs($path){
    if (test-path $path\silentargs.txt){
        $args = Get-Content $path\silentargs.txt
        return $args
    }
}


function checkChocoOnline($package, $onlineRepo) {
    # check version online
    $searchOnline = choco search -r -e $package.id -s $onlineRepo
    try { $currentVersion = [System.Version]$package.version }
    catch { $currentVersion = [System.Version]"0.0.0.0"}

    if ($searchOnline) {
        $onlineVersion = [System.Version] $searchOnline.Split("|")[1]
        if($onlineVersion -gt $currentVersion)
        {
            Write-Warning "Newer version of $($package.id) found. Downloading."
            $package.Outdated = $true
            $package.NewVersion = $onlineVersion

            #Download and internalize the package (we just need the download folder to recompile.)
            #TODO - support flags for install 
            choco download $package.id -r --internalize --force  --no-progress --out $chocoCustomFolder|out-null
            
            if ($LASTEXITCODE -ne 0)
            {
                Write-Warning ($package.id + ' internalize failed')
                $Failure.Add($package.id) | Out-Null
                $packages.where({$_.id -eq $package.id}).StatusMessage = $package.id + ' internalize failed'
                $package.Updated = $false
            }
            else{
                # Remove nupkg file and verify download file.
                if (-not (Test-Path $chocoCustomFolder\download\$($package.id) )) { 

                    $package.StatusMessage = "Failure: Missing the folder $chocoCustomFolder\download\$($package.id)"
                    $package.Updated = $false
                }
                else{
                    $package.Updated = $true
                    $package.StatusMessage = "A new version is awaiting recompile"
                }
                
                #Cleanup
                if (Test-Path $chocoCustomFolder\$($package.id)*.nupkg){
                    # Removing nupkg file in prep fore re-compile.
                    Remove-Item $chocoCustomFolder\$($package.id)*.nupkg -Force
                }
            }
        }
        else 
        { 
            $package.Outdated = $false
            $package.Updated = $false
            $package.NewVersion = $onlineVersion
        }

    }
    else {write-host ""}

    
}
function checkNetworkPath {
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [packageType]$package,
        [Parameter(Mandatory=$True,Position=1)]
        [string]$path,
        [Parameter(Mandatory=$True,Position=2)]
        [string] $filePattern
    )

    Write-Verbose "Running checkNetworkPath()"
    $custom_path = customPath($package)
    try { $currentVersion = [System.Version]$package.version }
    catch { $currentVersion = [System.Version]"0.0.0.0"}
    Write-Verbose "searching -> $path for $filePattern"
    $filelist = Get-ChildItem -Path $path -Filter $filePattern -File
    $versionsFound = @()
    $fileExtension = $filePattern.Substring($filePattern.Length - 3)
    foreach ($file in $filelist) {  
        Write-Verbose "checking file $($file.FullName)"
        $fileObject = New-Object -TypeName PSCustomObject -Property @{
            'filepath' = $file.Fullname
            'version' = $null
        }

        $version = $null
        try { 
            $version = [System.Version][System.Diagnostics.FileVersionInfo]::GetVersionInfo($file.Fullname).FileVersion
        }
        catch { $version = $null}
        
        # if we didnt get a version from the file properties - try the filename
        if (-not $version){
            $fileObject.version = $version      
            [regex] $version_regex = '^.*(\d+\.\d+\.(?:.*)\d+)\.' + "$fileExtension`$" 
            $matches = $version_regex.Match($file.FullName)
            if ($matches.Success){
                try { $fileObject.version = [System.Version] $matches.Groups[1].Value }
                catch { $version = $null}
            }
        }

        if ($fileObject.version){
            $versionsFound += $fileObject
        }

      
    }
 
    
    $newVersion = $versionsFound | Sort-Object -Property Version -Descending | Select-Object -first 1
    

    if ($newVersion.Version -gt $currentVersion)
    {
        $package.Outdated = $true
        $package.NewVersion = $newVersion.version
        $customArgs = checkForSilentArgs($custom_path)

        if ($customArgs){
            choco new --file $newVersion.filepath silentargs=$customArgs --out $chocoCustomFolder\download -r  |out-null
        }
        else{
            choco new --file $newVersion.filepath --out $chocoCustomFolder\download -r  |out-null
        }

        if ($LASTEXITCODE -ne 0)
        {
            Write-Warning ($package.id + ' creation of new package failed')
            $package.Updated = $false
        }
        else{
                $package.Updated = $true
                $package.StatusMessage = "A new version is awaiting recompile"
        }
                        
        
    }
    else 
    { 
        Write-Host "Package is already up to date $($package.id)" -ForegroundColor Yellow 
        $package.Outdated = $false
        $package.Updated = $false
        $package.NewVersion = $newVersion.version
    }
    
}


function copyPackageFiles($package){
    #Replaces files by looking in replacements folder in path. This should be an exact structure of the download repo folder. 
    $custom_path = customPath($package)
    $folder = Test-Path $custom_path\copyfiles
    

    if ($folder)
    { 
        try {
            Copy-Item -Force -Recurse $custom_path\copyfiles\* $chocoCustomFolder\download\$($package.id)\ 
            $package.StatusMessage = "Files successfully replaced. Awaiting re-compile"
            $package.Updated = $true
        }
        catch {
            $package.StatusMessage = "FAILED: Could not copy files from $custom_path\copyfiles to download\$(package.id)\"
            $package.Updated = $false
        }
    }
    else {
        $package.StatusMessage = "FAILED: $custom_path\copyfiles folder does not exist in current directory. Failing."
        $package.Updated = $false
    }
}

function customScript($package, $pathToScript){ 
### Custom Script - When you need to do some funky ### $$$$
    
    $custom_path = customPath($package)

    write-warning $custom_path 
    if (Test-Path $pathToScript)
    {
        $package.StatusMessage =   . $pathToScript($package)
    }
    elseif (Test-Path $Global:customPath\$pathToScript) {
        $package.StatusMessage =   . $Global:customPath\$pathToScript($package)
    }
    elseif (Test-Path $custom_path\$pathToScript) {
        $package.StatusMessage =   . $custom_path\$pathToScript($package)
    }
    else {
        $package.StatusMessage = "FAILED: Could not find script at $pathToScript"
        $package.Updated = $false
    }
}

function mergePackageFiles($package, $flags){
    #Merges files by looking in mergers folder in path. This should be an exact structure of the download repo folder. 
    #If XML or nuspec files are found , apply a XML merger

    $custom_path = customPath($package)
    $folder = Test-Path $custom_path\mergers
    $xmlTypes = (".xml",".nuspec")

    if ($folder)
    { 
        try {
            $items = Get-ChildItem -Path $custom_path\mergers\ -Recurse -File
            foreach ($file in $items)
            {
                $relativePath = ($file.Directory.FullName -split "mergers\\")[1]
                
                if ($relativePath)
                {
                    if (-not (test-path $chocoCustomFolder\download\$($package.id)\$relativePath)) {  New-Item $chocoCustomFolder\download\$($package.id)\$relativePath -Type Directory |out-null }
                }
                
                if ($xmlTypes -contains $file.extension)
                {
                    $originalFile = Get-Content -Path $chocoCustomFolder\download\$($package.id)\$relativePath\$file
                    $mergeFile = Get-Content -Path $file.FullName

                    ForEach ($XmlNode in $mergeFile.DocumentElement.ChildNodes) {
                        $originalFile.DocumentElement.AppendChild($originalFile.ImportNode($XmlNode, $true))
                    }
                    $originalFile | Out-File $chocoCustomFolder\download\$($package.id)\$relativePath\$file
                }
                else {
                   write-warning "Non XML types are not currently supported for merger $($file.Name)"
                   #TODO - Expand for other filetypes as needed
                }
            }
            $package.StatusMessage = "Files successfully replaced. Awaiting re-compile"
            $package.Updated = $true
        }
        catch {
            $package.StatusMessage = "FAILED: Could not copy files from $custom_path\copyfiles to download\$(package.id)\"
            $package.Updated = $false
        }
    }
    else {
        $package.StatusMessage = "FAILED: $custom_path\copyfiles folder does not exist in current directory. Failing."
        $package.Updated = $false
    }
}


function recompilePackage($package){
    choco pack "$chocoCustomFolder\download\$($package.id)\$($package.id).nuspec" --out $chocoPackages | Out-Null
    if ($LASTEXITCODE -ne 0)
    {
        Write-Warning "$($package.id) re-compile failed"
        $package.Updated = $false
        $package.StatusMessage = "$($package.id) re-compile failed"
    }
    else{
        $package.Updated = $true
        $package.StatusMessage = "$($package.id) successfully re-compiled pacakge. Awaiting upload"
    }
}



function defaultScript{
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [packageType]$package
    )

    $custom_path = customPath($repoPackage)
    $global:custom_path = $custom_path
    # Cleanup before we run.
    if (Test-Path $chocoCustomFolder\download\$($package.id)) { Remove-Item $chocoCustomFolder\Download\$($package.id) -Force -Recurse |out-null} 

    # Load the config file for this custom install
    $config = Get-Content $custom_path\config.json |ConvertFrom-Json

    #### MAIN SECTION - RUN THROUGH CONFIG ####
    if ($config.WebRepoSource.Enabled){
        checkChocoOnline $repoPackage $config.WebRepoSource.Address
    }
    elseif ($config.NetworkSource.Enabled) {
    checkNetworkPath -package $repoPackage  $config.NetworkSource.NetworkPath $config.NetworkSource.FilePattern
    }
    elseif ($config.WebsiteSource.Enabled) {
        customScript $repoPackage $config.WebsiteSource.ScriptPath
    }

    ## If newer package was found (updated) - run changes if needed, recompile
        
    if($repoPackage.Updated) {
        # Replace files and re-compile (should be by default)  
        if ($config.CopyFiles.Enabled) {  copyPackageFiles $repoPackage }
        if ($config.CopyFiles.Enabled) {  mergePackageFiles $repoPackage }
        if ($config.CustomScript.Enabled) {customScript $repoPackage $config.CustomScript.ScriptPath} 
        if ($config.RecompileNupkg.Enabled) {recompilePackage $repoPackage }
    }
}

