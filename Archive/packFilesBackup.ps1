# Powershell tool to produce release archives versions of AMX projects
# Created by Sam Shelton @ Solo Control
# Zip files created are saved in: "./Release"

# Set the command line parameters with default values if required
param([string]$apwFileName='', [string]$packType='')

# Utility Function to exit Script with dignity
function fnExitScript{
    param([string]$msg)

   # Write-Host ''
    Write-Host -Prompt ("`n" + $msg + "`n`n")
    exit
}

#Check the Command Line Params are valid
if($apwFileName == ''){
    fnExitScript('Missing Parameter: apwFileName')
}

# Set Temp Directory
$TempDir = 'packFilesTempStorage'

# Start Utility
Write-Host 'packFiles Release Tool'
Write-Host ''

# Get This Directory (To ignore it)
$CurDir = (Get-Item -Path ".\" -Verbose).Name.Split("\")[-1]

function fnGetVersionFromDateTime{
    $returnVar = $args[0].Year.ToString()
    $returnVar = $returnVar+$args[0].Month.ToString("00")
    $returnVar = $returnVar+$args[0].Day.ToString("00")+'.'
    $returnVar = $returnVar+$args[0].Hour.ToString("00")
    return       $returnVar+$args[0].Minute.ToString("00")
}

# Step back by one directory from Utils Directory
Set-Location '..'

#Function to Create Archive
function fnPackArchive{

    param([string]$Dir, [int]$Type)

    #Process each Amx Workspace File
    ForEach($apwFile in (Get-Item -Path $Dir).GetFiles('*.apw')){
    
        #Generate Archive Name
        if($Type -gt 0){
            (Get-Item -Path $Dir'\Source\').GetFiles('*.tkn')[0]
            $ArchiveName = fnGetVersionFromDateTime ( (Get-Item -Path $Dir'\Source\').GetFiles('*.tkn')[0]).LastWriteTime
            $ArchiveName = $apwFile.BaseName + '_' + $ArchiveName + '.zip'
            Write-Host 'Packing Archive:' $ArchiveName
            
            # Generate a temp folder name
            $TempProjDir =  $TempDir + '\' + $ArchiveName
            
            # Create a temporary folder 
            If(Test-path $TempProjDir) { Remove-item $TempProjDir -Recurse }
            If (!(Test-Path $TempProjDir)) { 
                $null = New-Item -Path $TempProjDir -ItemType Directory
            }
            # Create a Relase folder 
            If (!(Test-Path 'Release')) { 
                $null = New-Item -Path 'Release' -ItemType Directory
            }
        }
        else{
            Write-Host 'Verifying Files:' $apwFile.Name
        }
        
        # Load .apw as XML DOM
        [xml]$apwDOM = Get-Content $apwFile.FullName
        
        # Check all files can be found
        ForEach($FileNode In $apwDOM.SelectNodes("//File")){
            # Get Referenced FileName
            $FileParts = $FileNode.FilePathName.split("\")
            $FileActualPath  = ''
            $FileDesiredDir  = $TempProjDir
            $FileDesiredPath = $TempProjDir
            $FileRelativePath = ''

            if($FileParts[0] -eq '..'){
               $FileParts[0] = '.'
               $x = 1
               $y = 2
            }
            else{
                $FileActualPath = $Dir
                $x = 0
                $y = 0
            }
             # Get actual path
            For($i=$x; $i -lt $FileParts.Count; $i++){
                if($FileActualPath -ne ''){
                    $FileActualPath += '\' 
                }
                $FileActualPath   += $FileParts[$i]
            }

            # Get Desired Path
            For($i=$y; $i -lt $FileParts.Count; $i++){
                # Desired Path
                $FileDesiredPath += '\' 
                $FileDesiredPath += $FileParts[$i]
                # Relative Path
                if($FileRelativePath -ne ''){
                    $FileRelativePath += '\' 
                }
                $FileRelativePath += $FileParts[$i]
            } 

            # Get Stub Directory
            For($i=$y; $i -lt $FileParts.Count-1; $i++){
                $FileDesiredDir += '\'
                $FileDesiredDir += $FileParts[$i]
            }
            # Check or copy
            if($Type -eq 0){
                switch(Test-path $FileActualPath) { 
                    true  { Write-Host -NoNewline '--Found: '    }
                    false { 
                        Write-Host -NoNewline '--Missing: ' 
                        $FileMissing = 1
                    }
                }
                Write-Host $FileActualPath
            }
            else{
                 # Create directory if it doesn't exist
                If (!(Test-Path $FileDesiredDir)) { $null = New-Item -Path $FileDesiredDir -ItemType Directory }
                # Copy file
                Write-Host --Copying: $FileActualPath
                Write-Host -------To: $FileDesiredPath 
                If (!(Test-Path $FileDesiredPath)) { Copy-Item $FileActualPath $FileDesiredPath }
                # Alter .apw file to reflect new file position
                $FileNode.FilePathName = $FileRelativePath
            }
            
        }
        # Exit if any errors
        if($FileMissing){
            Write-Host ''
            Read-Host -Prompt "File(s) not found - Press Enter to Exit"
            exit
        }


        if($Type -gt 0){
            # Save XML to Workspace .apw
            $apwFileName = $pwd.ToString() + '\' + $TempProjDir + '\' + $apwFile
            $apwDOM.Save($apwFileName)
        
            # Move working directory into Temp so Zip starts from correct root
            Set-Location $TempProjDir
            # Delete Archive if already exists
            $RelArchive = '..\..\Release\' + $ArchiveName

            # Create a new Archive from .apw files
            Compress-Archive -DestinationPath $RelArchive -Path '*' -Force

            # Move working directory back to correct location
            Set-Location '..'
            Set-Location '..'

            # User Hint
            Write-Host 'Finished:' $ArchiveName
        }
        else{
            Write-Host 'Finished:' $apwFile.Name
        }
        Write-Host ''

    }
    # Remove Temp Folder
    if($Type -ne 0){
       If(Test-path $TempDir) { Remove-item $TempDir -Recurse }
    }
}


# For each child directory write as menu
$ChildDirs = Get-ChildItem '.' | ? {$_.PSIsContainer -AND $_.Name -ne $CurDir -and $_.GetFiles("*.apw").Count -ne 0 -and $_.GetFiles("*.ps1").Count -eq 0 }
$ChildDirs | %{$i=0} {Write-Host $i : $_.Name; $i++}

# Prompt for which prject to Release
Write-Host ''
$ProjectCount = $ChildDirs.Count
$Project = Read-Host -Prompt "Choose Project (0-$ProjectCount)"
if($Project -ne ''){
    Write-Host '1'
    if(0 -le $Project){
        # Verify Integrity
        fnPackArchive -Dir $ChildDirs[$Project].Name -Type 0
        # Pack up Full Dev Version
        fnPackArchive -Dir $ChildDirs[$Project].Name -Type 1
    }
}


# Wait for prompt before Exiting
Write-Host ''
Write-Host ''
Read-Host -Prompt "Finished - Press enter to close"