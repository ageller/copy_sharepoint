# copy_sharepoint

A bash script using rclone to copy files to or from SharePoint.  
The user must first install rclone and configure it to work with the particular SharePoint site of interest.  
Within the `copy_sharepoint.sh` script, the user must edit the `REMOTE_DIR` variable to point to the directory of interest.
This script is meant to be placed within the local directory that should be copied.  
The script will first compare file timestamps and provide the user with a list of differences (indicating whether the local or sharepoint versions are newer).  
Next the script gives the user the option to either copy from local to sharepoint or vice versa.  
