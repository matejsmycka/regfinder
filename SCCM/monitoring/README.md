# How it works
The project consist of following parts
#### Driver scripts
The mechanism of deploying configurations and monitoring scripts is simple. We use SCCM (Configuration Baseline/Item) to check periodically if the configuration that is here, in repository is identical. If the hash of `nsclient.ini` file is not identical, the file and monitoring scripts are replaced by latest version.    
This is done with Configuration Item and scripts from repository as follows `check.ps1` for check if the condition is met and `driver.ps1` (remediation script) that replaces files.
#### Pipeline
After each commit to the master branch the pipeline starts.   
It just calculate MD5 hash from changed nsclient.ini files and stores configurations and monitoring scripts on web server `sccm-01.ucn.muni.cz/monitoring`.    
It's required for all servers that use the SCCM nagios to have enabled 443 port to SCCM server. 
#### Configuration
The configuration files (`nsclient.ini`) are stored in `servers` folder in following hierarchy   
- /servers/ 
    + default/
        - scripts/   
            + check_one.ps1    
            + check_two.ps1
        - services/
            + service_one.exe
            + service_two.exe
        - nsclient.ini   
        - nsclient2.ini   
        - etc..  
    + ucn-server5/   
       - scripts/
            + haha.ps1
            ...

In the first case, all not listed servers are in category `default` so they will download configuration and scripts from default sub-folder.   
If the server has it's own configration it has to have it's own sub-folder with files that will be downloaded by the server. The matching is done by Windows host name (NETBIOS name).
