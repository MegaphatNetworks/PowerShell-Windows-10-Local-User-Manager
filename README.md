# Windows 10 Local User Manager
## by Gabriel Polmar                                      
## Megaphat Networks                                      
## www.megaphat.info                                      

## IMPORTANT: This script will allow you to manage local users on your system.  That said, let's move on.

### INTRODUCTION.  

So Back in early 2020 I released the [Windows 10 Exorcist  v1](https://github.com/MegaphatNetworks/Windows-10-Exorcist-v1) and one of the problems with Windows 10 is the Local User Management is intertwined with connecting with Microsoft.  This means you cannot manage local users without being able to access Microsoft.  Since the Exorcist disables ALL telemetry with Microsoft as well as other "phone home" features, users of Windows 10 (especially Home) were unable to manage local users.  Windows 10 Pro and Enterprise you can simply go to Computer Manager and access the Local Users and Groups but that is not available on Home.  So I figured I boo boo'd and now I will provide the means to manage your local users without compromising the integrity of your system by opening it up to a huge mess of Microsoft bloating.  

This is a PowerShell script.  It's GUI-based.  You execute the script, it will self-elevate to Administrator.  It's really self explanatory.  More info to come.

### ABOUT THE CODE: 
Please note that it took about 22 hours of research, 85 hours of coding and testing to get this script working.   
If you find it useful, please give us credit if you clone the script.  If you really want to show your thanks, I would appreciate 
any donation you could make to help pay for the time I spend doing this as well as getting me more coffee to keep me coding!    
