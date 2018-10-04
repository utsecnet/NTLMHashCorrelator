<#
.SYNOPSIS
    Create a human readable csv file of all cracked passwords on your domain.  Useful for auditing password 
    strength and other fun stuff ;)

.DESCRIPTION
    - Takes the fgdump text file, and creates two files:
        hashFile.txt: A cleaned up file that matches usernames to hashes
        hashesForCracking.txt: a file with only hashes that will be used to paste to http://finder.insidepro.com/ 
                               for cracking the hashes
    - Paste the results of the crack to a file, crackedFile.txt, and press OK on the message box to continue
      This file matches the hash to the pasword.
    - Correlates the username in the hashFile.txt with the cracked password in crackedFile.txt and builds a csv 
      file with the following columns:
        Username, Department, Hash, Password
    - Please note, only active enabled AD accounts are checked.  Disabled accounts are not checked.

.REQUIREMENTS
    - On your domain controller, temporarily disable your AV Active Protection
    - Copy fgdump to the domain controller and run /release/fgdump.exse as administrator
    - Copy the hash dump to your machine
    - You must have a directory structure as dictated by the variable below: $directory
    - You must copy the fgdump password hash file into this directory
        Note: the name may be different depending on the options you selected when running fgdump.  
              Verify the name of the dump file matches the variable $hashDump below

.NOTES
    NAME: userPasswordHashAlignmentTool.ps1
    AUTHOR: Rich Johnson
    EMAIL: rjohnson@upwell.com
    Change Log:
        2017-10-17 - Initial Creation

.TODO
    - Move exisitng files into a directory with date/time, rather than delete for archiving purposes
    - encrypt the contents of archived folder to maintain confendentiality (Until then, manual encryption with 
      AxCrypt suggested!)

#>

############
# Variables
############

# Directory where files will be handled
$directory = "C:\Users\rjohnson\Documents\Hashcrack"

# File that contains the original hash dump from your AD server.
$hashDump = "$directory\127.0.0.1.pwdump" 

# Cleaned up hashDump file 
$hashFile = "$directory\hashFile.txt"

# list of only the hashes.  The contents of this file will be copy/pasted to finder.insidepro.com for cracking
$hashesForCracking = "$directory\hashesForCracking.txt"

# File that contains the cracked hashes that you get from finder.insidepro.com
$crackedFile = "$directory\crackedFile.txt"

# The file this script contains that aligns cracked hashes with user accounts
$finishedFile = "$directory\finishedFile.csv"

# Create an object from the hashDump file for futher processing
$hashDumpObject = Get-Content $hashDump

############
# Functions
############

# Deletes a single file if found
function deleteFile ($fileName) {
    if (test-path $fileName) {
        Remove-Item $fileName
    }
}

###################
# Aaaaaand ACTION!
###################

# Delete an exisiting file so we dont keep appending to it
deleteFile "$finishedFile"
deleteFile "$hashFile"
deleteFile "$crackedFile"
deleteFile "$hashesForCracking"

# Clean up the hashDump file, create a new file with username:hash, and leave the original untouched
if (test-path $hashDump) {
    foreach ($line in $hashDumpObject) {
        $username = ($line -split ':')[0]
        $hash = ($line -split ':')[3]

        # Create the cleaned up hashFile
        "$($username):$hash" | Out-File $hashFile -Append

        # Create a second file with a list of only the hashes.  This will be uploaded to http://finder.insidepro.com for cracking
        $hash | Out-File $hashesForCracking -Append
    }

    # Create an object from the hashfile for later processing
    $file1 = Get-Content $hashFile
}

# Copy the contents of hashFile to clipboard
cat $hashesForCracking | clip

# Open the URL to manually paste all the hashes in
Start "http://finder.insidepro.com/"

# Display a message about pasting the hashes
[System.Windows.MessageBox]::Show("We have copied the hashes to your clipboard.  `n`nSimply paste them into the Hash Finder web tool that should open in a browser.  `n`nIf Hash Finder successfully cracks any hashes, paste the results into $directory\crackedFile.txt and save the file.`n`nOnly when this is done, press OK to continue.",'Paste your hashes','OK','Information')
if (!(Test-Path $crackedFile)) {
    Write-Output "Did you forget to read the pop-up message?  You need to save the file $directory\crackedFile.txt!"
    exit
}

# Clear the contents of the clipboard
Set-Clipboard -Value $null

# Manually save the cracked file before continuing!
# Create an object from the crackedFile for futher processing
$file2 = Get-Content $crackedFile

# Create the file and column headers
Add-Content -Path $finishedFile -Value '"Name","Department","Hash","Password"'

# Get each hash and password in the $crackedFile file
foreach ($value in $file2) {
    
    $crackedHash = ($value -split ':')[0]
    $crackedPass = ($value -split ':')[1]
    
    foreach ($user in $file1) {
        
        $username = ($user -split ':')[0]
        $hash = ($user -split ':')[1]

        if ($hash -eq $crackedHash) {
            
            # Import the AD module so you can use the get-aduser cmdlet
            If (!(Get-module ActiveDirectory )) {
                Import-Module ActiveDirectory
            }

            if ($(get-aduser $username -Properties enabled,department).enabled -eq "True") {
                $department = Get-ADUser $username -Properties department | select -ExpandProperty department

                # Populate the array with user spcific values
                #$array.Add("$username","$department","$hash","$crackedPass")
                #$array += @('"$username","$department","$hash","$crackedPass"')
                write-output "$username, $department, $hash, $crackedPass" >> $finishedFile
            }
        }
    }
}