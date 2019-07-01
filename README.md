# chocolatey-packages
Chocolatey Package Updater

This PowerShell script executes against our internal repository to create a list of packages to check for updates and internalize.

# Features
* Automatically internalizes packages available on internal repo.
* Send summary email to group when new packages are available.
* Custom scripts can be executed to handle non-standard packages

Templates are provided for :
* Check for newer version on choco online repo
* Check for newer version scraping a website
* Check for newer version on a network share
* Check for a newer version using a custom script.
* Update package by replacing files in nupkg
* Update package by merging files in nupkg
* Recompile packages for upload after custimization.


# Installation
This script requires minimally PowerShell version 5: $host.Version -ge '5.0'

To install it please clone the repo to c:\git\choco-packages
`git clone`

NOTE: All script functions work from within this specific root folder. 

# Usage

Simply point a scheduled task or run updateFromRepo.ps1 in the root folder.

To create a template, copy the c:\git\choco-packages\custom-packages\Template folder to a new folder in the same path and rename it to the desired package name.

Example: `copy-item Template Office365ProPlus`

You can change what is executed by  editing the xml configuration file. (This is loaded as a variable in powershell)
For super custom installs, you can write and execute a customScript.ps1. Although most conditions should be handled with the templates.
