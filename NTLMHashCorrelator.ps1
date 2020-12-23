<#
.SYNOPSIS
    Create a human readable csv file of all cracked passwords on your domain.  Useful for auditing password strength and other fun stuff ;)

.DESCRIPTION
    - Takes the fgdump text file, and creates two files:
        hashFile.txt: A cleaned up file that matches user names to hashes
        hashesForCracking.txt: a file with only hashes that will be used to paste to https://a.ndronic.us/pw for cracking the hashes
    - Paste the results of the crack to a file, crackedFile.txt, and press OK on the message box to continue
      This file matches the hash to the password.
    - Correlates the username in the hashFile.txt with the cracked password in crackedFile.txt and builds a csv 
      file with the following columns:
        Username, Department, Hash, Password
    - Please note, only active enabled AD accounts are checked.  Disabled accounts are not checked.

.REQUIREMENTS
    - On your domain controller or local computer, temporarily disable your AV Active Protection
    - Download fgdump: http://www.foofus.net/fizzgig/fgdump/fgdump-2.1.0.zip
    - Extract the files and run /release/fgdump.exe as administrator on your local computer or on a Domain Controller
    - Copy the hash dump to your workstation (if on a DC)
    - You must have a directory structure as dictated by the variable below: $directory
    - You must copy the fgdump password hash file into this directory (if copying from a DC)
        Note: the name may be different depending on the options you selected when running fgdump.  
              Verify the name of the dump file matches the variable $hashDump below

.PARAMETERS
    This script takes one optional parameter: $ad
        $ad: when specified, the script uses some get-aduser cmdlets to pull user information from Active Directory

    .Example
        >.\userPasswordHashAlignmentTool.ps1 -ad
        Used when using a password dump from a domain controller.

        >.\userPasswordHashAlignmentTool.ps1
        Without specifying the ad parameter, it assumes you are cracking a hash file take from 
        a local computer's SAM database


.NOTES
    NAME: userPasswordHashAlignmentTool.ps1
    AUTHOR: Rich Johnson
    EMAIL: rjohnson@utsec.net
    Change Log:
        2020-07-03 - Updated to use a.ndronic.us/pw
                   - performance tweaks
                   - Added the $ad parameter so you can test passwords from your domain controller or local SAM file
        2017-10-17 - Initial Creation

.TODO
    - Move exisitng files into a directory with date/time, rather than delete for archiving purposes
    - encrypt the contents of archived folder to maintain confendentiality (Until then, manual encryption suggested!)

#>

############
# Parameters
############

# If a parameter is passed to the script, will use get-aduser for user information
param([switch]$ad = $false)


############
# Variables
############

# Directory where files will be handled
$directory = "C:\Users\unass\Downloads\fgdump-2.1.0\Release"

# File that contains the original hash dump from your AD server.
$hashDump = "$directory\127.0.0.1.pwdump" 

# Cleaned up hashDump file 
$hashFile = "$directory\hashFile.txt"

# list of only the hashes.  The contents of this file will be copy/pasted to a.ndronic.us/pw for cracking
$hashesForCracking = "$directory\hashesForCracking.txt"

# File that contains the cracked hashes that you get from a.ndronic.us/pw
$crackedFile = "$directory\crackedFile.txt"

# The file this script contains that aligns cracked hashes with user accounts
$finishedFile = "$directory\finishedFile.csv"

# Create an object from the hashDump file for further processing
$hashDumpObject = Get-Content $hashDump

# URL of the site you will paste hashes to
$crackUrl = "https://a.ndronic.us/pw"

# Number of characters in a line from the returned cracked password results
$passChar = 35

# Create thfinal file
if ($ad -eq $true) {
    Add-Content -Path $finishedFile -Value '"Name","Department","Hash","Password"'
}
else {
    Add-Content -Path $finishedFile -Value '"Name","Hash","Password"'
}

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

# Delete an existing file so we don't keep appending to it
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

        # Create a second file with a list of only the hashes.  This will be uploaded for cracking
        $hash | Out-File $hashesForCracking -Append
    }

    # Create an object from the hashfile for later processing
    $file1 = Get-Content $hashFile
}

# Copy the contents of hashFile to clipboard
cat $hashesForCracking | clip

# Open the URL to manually paste all the hashes in
Start $crackUrl

# Display a message about pasting the hashes
[System.Windows.MessageBox]::Show("We have copied the hashes to your clipboard.  `n`nSimply log in and paste them into the Hash Finder web tool that should open in a browser.  `n`nIf Hash Finder successfully cracks any hashes, paste the results into $directory\crackedFile.txt and save the file.`n`nOnly when this is done, press OK to continue.",'Paste your hashes','OK','Information')
if (!(Test-Path $crackedFile)) {
    Write-Output "Did you forget to read the pop-up message?  You need to save the file $directory\crackedFile.txt!"
    Write-Output "Run the script again, and don't forget to do this!"
    exit
}

# Manually save the cracked file before continuing!
# Create an object from the crackedFile for further processing
$file2 = Get-Content $crackedFile

# Get each hash and password in the $crackedFile file
# NOTE: You may end up with a smaller list of passwords after the script finishes than cracked hashes.  
# This section only aligns enabled users.
foreach ($value in $file2) {

    # Lines with successfully cracked passwords will contain greater than $passChar characters
    # Filter out all the rest
    $charCount = $value | Measure-Object -Character
    if ($charCount.Characters -gt $passChar) {

        $crackedHash = ($value -split ":::")[0]
        $crackedPass = ($value -split ":::")[1]

        # go through the original hash file to see which users have cracked passwords
        foreach ($user in $file1) {

            $username = ($user -split ':')[0]
            $hash = ($user -split ':')[1]

            if ($hash -eq $crackedHash) {

                # If you specified the $ad parameter
                if ($ad -eq $true) {

                    # Create the file and column headers
                    

                    # Import the AD module so you can use the get-aduser cmdlet
                    If (!(Get-module ActiveDirectory )) {
                        Import-Module ActiveDirectory
                    }

                    if ($(get-aduser $username -Properties enabled,department).enabled -eq "True") {
                        $department = Get-ADUser $username -Properties department | select -ExpandProperty department

                        # Add rows to the final file
                        write-output "$username, $department, $hash, $crackedPass" >> $finishedFile
                    }
                }

                # If you did not specify the $ad parameter
                else {

                    # Create the final file
                    Write-Output "$username, $hash, $crackedPass" >> $finishedFile

                }
            }
        }
    } 
}
