When packages are inernalized and the replacement function is run - this folder will be parsed to replace files inside the chocolatey package (nupkg) file.

The structure of the path looks like:

\files\setup.exe
\chocolateyInstall.ps1t
\configuration.xml
\packageName.nuspec

etc

So if you want to replace the nuspec file. Place a replacement (named after the package) in the root of the REPLACEMENTS FOLDER.

(This folder)