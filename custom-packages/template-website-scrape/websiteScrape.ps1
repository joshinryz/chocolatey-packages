### Author: Joshua Robinett 
### Email:  josh.robinett@gmail.com            
### Github: @jshinryz

########## PARAM TAKE IN OUR PACKAGE VARIABLE FROM MAIN SCRIPT TO UPDATE
param(
    [packageType]$package
)

try {
    . .\lib\package_class.ps1
    . .\lib\base_CustomInstall.ps1 
    }
catch { Write-Warning "Unable to find include files in $(get-location). Returning False" ; return $false}

## TODO: REMOVE

#TESTING
#$package = [packageType]::new()
#$package.id = "package-name"

$package


#######
#Configure these options
#######
$website = "https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html"
$downloadSearchString = "putty-64bit*.msi"
$needToLogin = $false
$username = "username"
$password = "password"
######


class downloadFile {
    [System.Version] $version = 0.0.0.0
    [string] $link = ""
    [string] $filename = ""
    [string] $filepath
}

function websiteLogin{
    #TODO - Need to make this more dynamic to test logins
    $webPage = Invoke-WebRequest -URI $webSite -SessionVariable my_session
    $loginform = $webPage.Forms |Where-Object {$_.Id -like 'authentication'}
    if ($loginform) {
        $loginform.Fields['username'] = $username
        $loginform.Fields['password'] = $password
        #TODO -  ADD TRY CATCH
        $request = Invoke-WebRequest -Uri ($website + "cgi-bin/" + $form.Action) -WebSession $my_session -Method POST -Body $form.Fields 
    }
    return $my_session
}



$currentVersion = [System.Version]$package.version

#TODO -  ADD TRY CATCH
if ($needToLogin){
    $webSession = websiteLogin
    $request = Invoke-WebRequest -URI $webSite -WebSession $webSession -Method Get
}
else{
    $request = Invoke-WebRequest -URI $webSite -SessionVariable webSession -Method Get
}

$fileLinks = $request.links | Where-Object {$_.outerText -like $downloadSearchString }

$versionTable = @()
if ($fileLinks)
{
    foreach ($file in $fileLinks){
        $download = [downloadFile]::new()
        $download.filename = $file.innerText
        $download.version = [System.Version]$($download.filename -split '-|.exe|.msi|.zip|x64.|x32.|_' | Where-Object {$_ -match "^\d+.\d+" })
        $download.link = $file.href
        $versionTable += $download 
    }
}

    
$newestVersion = $versionTable | Sort-Object -Property version -Descending | Select-Object -First 1

if ($newestVersion.version -gt $currentVersion){
    
    Invoke-WebRequest -Uri ($newestVersion.link) -WebSession $webSession -Method Get -OutFile ($chocoCustomFolder + "\download\" + $newestVersion.filename)
    Write-Warning $chocoCustomFolder
    if (Test-Path $($chocoCustomFolder + "\download\" + $newestVersion.filename) ){
        $newestVersion.filepath = ($chocoCustomFolder + "\download\" + $newestVersion.filename)
    }
    else {
        #FAIL
    }

    $package.Outdated = $true
    $package.NewVersion = $newestVersion.version
    $customArgs = checkForSilentArgs($custom_path)
    if ($customArgs){
        choco new --file $newestVersion.filepath silentargs=$customArgs --out $chocoCustomFolder\download --name=$($package.id) -r  |out-null
    }
    else{
        choco new --file $newestVersion.filepath --out $chocoCustomFolder\download -r --name=$($package.id) |out-null
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
 


