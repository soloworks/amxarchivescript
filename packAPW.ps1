# Powershell tool to produce release archives versions of AMX projects
# Created by Sam Shelton @ Solo Control
# Zip files created are saved in: "./Release"

# Set the command line parameters with default values if required
param([string]$File='', [string]$Mode='', [string]$Ver='')

# Set version if not supplied as a parameter
if($Ver -eq ''){
    $Ver = Get-Date -UFormat "%Y-%m-%d" # Add %H%M for Hours and Mins
}

# Script Variables and Constants
[string]$apwFileName = $File+'.apw'
[string]$zipFileName = $File+'_'+$Mode+'_'+$Ver+'.zip'

[int32]$packModeTypeRelease  = 0
[int32]$packModeTypeHandover = 1
[int32]$packModeTypeTransfer = 2

[string]$msg = ''

# Check the Command Line Has a valid filename passed
if($File -eq ''){
    echo("Error Running packAPW: Missing -File Parameter`n")
    exit
}

# Check the file exists
if(!(Test-Path $apwFileName)){
    echo("Error Running packAPW: File "+$apwFilename+" not found`n")
    exit
}

# Check mode is supported
switch($Mode){
    'Release' { $packModeType = $packModeTypeRelease  }
    'Handover'{ $packModeType = $packModeTypeHandover  }
    'Transfer'{ $packModeType = $packModeTypeTransfer  }

}

# Output current settings to be used
echo("Running packAPW on file "+$apwFileName+" in "+$Mode+' Mode')

# Load .apw as XML DOM
[xml]$apwDOM = Get-Content -Path $apwFileName

# Proceed with Verification process
echo('')
echo('Verifying Files in '+$apwFileName)


# Process the Global section
ForEach($ProjectNode In $apwDOM.SelectNodes("//Project")){
        # Find the _Global or Global project if it exists
    if($ProjectNode.Identifier -eq '_Global' -Or $ProjectNode.Identifier -eq 'Global'){
                Echo $ProjectNode
        # if this is a release then remove the whole project
        if($packModeType -eq $packModeTypeRelease){
            $parent = $ProjectNode.ParentNode
            $null = $parent.RemoveChild($ProjectNode)
        }
        elseif($packModeType -eq $packModeTypeHandover){
            # if this is a Handover then swap modules for tkos and remove Includes
            ForEach($FileNode In $ProjectNode.SelectNodes(".//File")){
                Echo $FileNode
                # Rename Modules
                if($FileNode.Type -eq 'Module' -And $FileNode.FilePathName.IndexOf('.axs') -ge 0){
                    $FileNode.FilePathName = $FileNode.FilePathName.Replace(".axs",".tko")
                    $FileNode.Type = 'TKO'
                } 
                    
                # Remove Includes
                if($FileNode.Type -eq 'Include'){
                    $parent = $FileNode.ParentNode
                    $null = $parent.RemoveChild($FileNode)
                }
                    
                # Remove Sources
                if($FileNode.Type -eq 'MasterSrc'){
                    $parent = $FileNode.ParentNode
                    $null = $parent.RemoveChild($FileNode)
                }

            }
        }
    }
}

# Check all files are present
$ErrorWithFiles = $false

ForEach($FileNode In $apwDOM.SelectNodes("//File")){
    if($packModeType -eq $packModeTypeRelease){

        # Remove Includes and Modules if this is a Release
        if($FileNode.Type -eq 'Module' -Or $FileNode.Type -eq 'Include'){
            $parent = $FileNode.ParentNode
            $null = $parent.RemoveChild($FileNode)
            Continue
        }

        # Change Source Code File if required
        if($FileNode.Type -eq 'MasterSrc'){
            $FileNode.FilePathName = $FileNode.FilePathName.Replace(".axs",".tkn")
            $FileNode.Type = 'TKN'

            # Add Device Mapping if not present
            if($FileNode.SelectNodes("DeviceMap").Count -eq 0){
                # Create DeviceMap Node
                $DeviceMapNode = $apwDOM.CreateElement("DeviceMap")

                # Create DeviceMap DevAddr Attribute
                $DeviceMapAtt  = $DeviceMapNode.OwnerDocument.CreateAttribute("DevAddr")
                $null = $DeviceMapNode.Attributes.Append($DeviceMapAtt)
                $null = $DeviceMapNode.SetAttribute("DevAddr","Custom [0:1:0]")

                    # Create DevName Node
                $DevNameNode = $apwDOM.CreateElement("DevName")
                $DevNameText = $apwDOM.CreateTextNode("Custom [0:1:0]")
                $null = $DevNameNode.AppendChild($DevNameText)

                # Add Devname to DeviceMap
                $null = $DeviceMapNode.AppendChild($DevNameNode)

                # Add DeviceMap to FileNode
                $null = $FileNode.AppendChild($DeviceMapNode)
            }
        }

    }
    
    # Check files exist
    switch(Test-path $FileNode.FilePathName) { 
        true  { Write-Host -NoNewline '--Found:   '    }
        false { 
                Write-Host -NoNewline '--Missing: ' 
                $ErrorWithFiles = $TRUE
        }
    }
    Write-Host $FileNode.FilePathName
   
}

# Exit if any files are missing
 if($ErrorWithFiles){
    echo("Aborting Packing Process")
 }

# Pack the Archive
echo('')
echo('Preparing Files for: '+$zipFileName)

# Set Temp Directory name
$TempDir = 'packAPWtemp_'+$File

# Remove Temp Folder if it exists
If(Test-path $TempDir) { Remove-item $TempDir -Recurse }
        
# Create Temp folder 
If (!(Test-Path $TempDir)) { 
    $null = New-Item -Path $TempDir -ItemType Directory
}

# Copy Files Across
ForEach($FileNode In $apwDOM.SelectNodes("//File")){
    # Get the current Filename
    $FileName  = $FileNode.FilePathName
    $FileParts = $FileNode.FilePathName.split("\")
    
    # Make a new filename using only last part of path
    $newFileName = $FileParts[-1]

    # Make a new folder name
    $newFileName = $FileParts[-1]

    # Add stub directory if present
    if($FileParts.Count -gt 1){
        # Pad out the new file with the stub
        $newFileName = $FileParts[-2]+'\'+$newFileName

        # Make a temp Folder variable
        $tempStubFolder = $TempDir+'\'+$FileParts[-2]

        # Create stub directory if it doesn't exist
        If (!(Test-Path $tempStubFolder)) { $null = New-Item -Path $tempStubFolder -ItemType Directory }
    }

    

    # Copy file
    Write-Host --Copying: $FileName
    $tempFileName = $TempDir+'\'+$newFileName
    Write-Host -------To: $newFileName 


    If (!(Test-Path $tempFileName)) { Copy-Item $FileName $tempFileName }

    # Alter .apw file to reflect new file position
    $FileNode.FilePathName = $newFileName
}

 # Save XML to Workspace .apw
 $apwDOM.Save($pwd.ToString() + '\' + $TempDir + '\' + $apwFileName)

 
# Pack the Archive
echo('')
echo('Packing: '+$zipFileName)

 # Create a Release folder 
If (!(Test-Path 'Release')) { 
    $null = New-Item -Path 'Release' -ItemType Directory
}

        
# Move working directory into Temp so Zip starts from correct root
Set-Location $TempDir

# Set archive name
$RelArchive = '..\Release\' + $zipFileName

# Create a new Archive from .apw files
Compress-Archive -DestinationPath $RelArchive -Path '*' -Force

# User Hint
Write-Host 'Finished'
Write-Host ''

# Remove Temp Folder
Set-Location '..'
If(Test-path $TempDir) { Remove-item $TempDir -Recurse }
