# Running Docker on WSL2 without Docker Desktop

# Overview
These scripts enables a docker environment on Windows 10 without the need for Docker Desktop.

# What the scripts do
1. Enables WSL and Hyper-V if needed
2. Install kernel update for wsl2
3. Downloads latest Alpine Distro and creates a wsl distribution named LocalDockerHost
4. Runs an sh script that installs docker in the alpine distro

# Running the script
1. Open a powershell as administrator
2. Make sure your execution policy is set to at least RemoteSigned
```
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned
```
3. Clone the repo
```
git clone https://github.com/Shurugwi/Wsl2Docker.git
```
4. Run the powershell script
```
.\Wsl2Docker.ps1
```
