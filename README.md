# copy_sharepoint

A bash script using rclone to copy files to or from SharePoint.  

Prior to running the script:
- Install [rclone](https://rclone.org/) and configure it to work with the particular SharePoint site of interest.  
- Copy the `copy_sharepoint.sh` script to the local directory that should be copied.
- Within that `copy_sharepoint.sh` script, edit the `REMOTE_DIR` variable to point to the directory of interest.

Run the script from the (bash) command line with:
```
./copy_sharepoint.sh
```

The script will first compare file timestamps and provide the user with a list of differences (indicating whether the local or sharepoint versions are newer).  Next the script gives the user the option to either copy from local to sharepoint or vice versa.  
