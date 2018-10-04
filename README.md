# NTMLHashCorrelator

## How do I use this script?

1. Download and extract fgdump to your Domain Controller.  You will need to temporarily disable Antivirus.
2. Navigate to the **..\fgdump-#.#.#\Release** directory, and run **fgdump.exe as administrator**.
3. Create a directory structure on your machine like: **C:\Users\yourAccount\Documents\Hashcrack**
4. Copy the **127.0.0.1.pwdump** file fgdump creates to the Hashcrack directory
5. Run the **NTMLHashCorrelator.ps1** script

The script then creates two files in the Hashcrack directory:

**hashFile.txt**: A cleaned up copy of the .pwdump file that includes only the username and their respective hash.  Will be used to correlate the resulted cracked password to the username.

**hashesForCracking.txt**: A cleaned up copy of the hashFile.txt that only includes the hashes.  Used to paste into our online crack tool which is used in the next step.

Once these files are completely generated (may take up to a minute), the script will copy the contents of the hashesForCracking.txt file to your clipboard and open http://finder.insidepro.team/, an online tool I have found useful in cracking large amounts of hashes at once.  It will also open a message box with the next steps needed to finish the process.

6. Paste (ctrl+v) into the hashes textbox on the website
7. Copy the resulting cracked hashes and passwords into a new file in the Hashcrack directory called **crackedFile.txt**.
8. Press the OK button on the message box.

The script will then create **finishedFile.csv** which will have a table containing the user name, department, hash, and password.

## Things to be aware of

1. Shift + Delete the fgdump directory (permanent delete) on the Domain Controller and re-enable Antivirus
2. If you want to hold on to the resulting cracked files and even the dump files, it would be smart to encrypt the files on disk, even if you have BitLocker enabled. I highly recommend AxCrypt 1.7 which allows you to right-click any file or directory and encrypt with a key or passcode.
3. Large amounts of sensitive data will be stored in your clipboard for a short time while you paste the hashes into the hash crack website. While the powershell script does clear the clipboard, you should be aware that running this tool on a less than trusted machine could put your credentials at risk.
