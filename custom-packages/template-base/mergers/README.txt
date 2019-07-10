When packages are inernalized and the merger function is run - this folder will be parsed to merge files inside the chocolatey package (nupkg) file.

The structure of the path looks like:

\files\answers.xml
\chocolateyInstall.ps1
\configuration.xml
\packageName.nuspec

etc

So if you want to merge the nuspec file. Place a file (named after the package) in the root of the REPLACEMENTS FOLDER.

Merger rules:

1.) Find and replace existing key value pair (string)
2.) If no match - insert merge line at buttom of file.

