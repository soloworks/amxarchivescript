# AMXPowerShell : Some scripts for packaging of AMX by Harman Netlinx Studio projects

## Overview
This repo contains some complex PowerShell scripts for packing up AMX projects into ZIP Archives whilst maintaining file structure and adding date stamps.

They are not pretty, but are functional. They are now legacy, to be replaced with a more efficient and reliable Go based packing tool.

## Use

Prior to using, you may need to elevate your privialges in PowerShell to allow scipts. You can do this by starting PowerShell and running:
```
Set-ExecutionPolicy Unrestricted
```
Easiest method of calling the working script is to create a batch file in the root of your project that you can call with a doubleclick:
```
@ECHO OFF
PowerShell.exe -ExecutionPolicy Bypass -Command "..\amxpowershell\PowershellScripts\packAPW.ps1 -File MyApwWorkspaceName -Mode Release"
PAUSE
```
Three types of package can be produced by changing the Mode argument:
- Release: Archive with only the compiled main file(s)
- Handover: Archive with main source code and compiled modules
- Transfer: Archive with all referenced files (as per .apw)

## Author

Created by Solo Works London, maintained by Sam Shelton 

Find us at https://soloworks.co.uk/