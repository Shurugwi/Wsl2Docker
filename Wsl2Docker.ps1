# This script needs to run with elevated privileges as it needs to make system changes.
# ExecutionPolicy must be set to run sctipts. At least for the current user.
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
# or
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

$DefaultWslFolder = "c:\Wsl"

function RebootPending {
    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
    try { 
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if (($null -ne $status) -and $status.RebootPending) {
            return $true
        }
    }
    catch { }

    return $false
}

function GetAlpineVersion {
    $versionContent = (Invoke-WebRequest -Uri "https://alpinelinux.org/downloads").Content
    $av = (((Select-String -InputObject $versionContent -Pattern "<strong>(.+?)</strong>" | Select-Object -ExpandProperty Matches -First 1 | Select-Object -ExpandProperty Value) -replace "<strong>", "") -replace "</strong>", "")
    Write-Host "Latest Alpine Version is:" $av
    return $av
}

function DownloadAlpineImage {
    $AlpineVersion = GetAlpineVersion
    $AlpineVersionSegments = $AlpineVersion.Split(".")
    
    $AlpineImageUrl = "https://dl-cdn.alpinelinux.org/alpine/v$($AlpineVersionSegments[0]).$($AlpineVersionSegments[1])/releases/x86_64/alpine-minirootfs-$($AlpineVersionSegments[0]).$($AlpineVersionSegments[1]).$($AlpineVersionSegments[2])-x86_64.tar.gz"    
    Write-Host "Alpine Image Url $($AlpineImageUrl)"

    $MyDocumentsFolder = [Environment]::GetFolderPath(“mydocuments”)

    $AlpineImageFileName = "$($MyDocumentsFolder)\AlpineImage$($AlpineVersion).tar.gz"

    if(![System.IO.File]::Exists($AlpineImageFileName))
    {
        Write-Host "Downloading Alpine image version $($AlpineVersion)"
        Invoke-WebRequest -Uri $AlpineImageUrl -OutFile $AlpineImageFileName
    }
    else 
    {
        Write-Host "Alpine image is latest version. Not downloading."
    }

    return $AlpineImageFileName
}

if(RebootPending)
{
    Write-Host "Your computer needs to be restarted before running this script again."
    exit
}

$IsElevated = ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq "False")
if(!$IsElevated)
{
    Write-Host "This script needs to be run with elevated privileges (Run as Administrator)"
    exit
}

$NeedsPcRestart = $false

#Enable WSL if needed
if((Get-WindowsOptionalFeature -Online -FeatureName:Microsoft-Windows-Subsystem-Linux).State -eq "Disabled")
{
    Write-Host "Wsl needs to be enabled"
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    $NeedsPcRestart = $true
    Write-Host "Wsl has been enabled. This will be completed after a restart."
}
else
{
    Write-Host "Wsl is enabled"
}

#Enable HyperV if needed
if((Get-WindowsOptionalFeature -Online -FeatureName:VirtualMachinePlatform).State -eq "Disabled")
{
    Write-Host "HyperV needs to be enabled"
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    $NeedsPcRestart = $true
    Write-Host "HyperV has been enabled. This will be completed after a restart."
}
else
{
    Write-Host "HyperV is enabled"
}

if($NeedsPcRestart)
{
    Write-Host "Your computer needs to be restarted before wsl can be used."
    Restart-Computer -Confirm
    exit
}

$AlpineImageFileName = DownloadAlpineImage
$wsloutput = (& wsl -l -q)

if($wsloutput -contains "LocalDockerHost")
{
    Write-Host "Docker Wsl Image already exists. Run the following command to remove it:"
    Write-Host "wsl --unregister LocalDockerHost"

    Write-Host "Run the following command to start an instance:"
    Write-Host "wsl -d LocalDockerHost"
}
else 
{
    Write-Host "Creating WSL docker environment. This may take a few minutes..."

    $DockerHostFolder = "$($DefaultWslFolder)\LocalDockerHost\"

    if(![System.IO.Directory]::Exists($DefaultWslFolder))
    {
        [System.IO.Directory]::CreateDirectory($DefaultWslFolder)
        [System.IO.Directory]::CreateDirectory($DockerHostFolder)
    }

    $DefaultWslFolder
    $DockerHostFolder
    $AlpineImageFileName

    $wsloutput = & wsl --import LocalDockerHost $DefaultWslFolder $AlpineImageFileName
    $wsloutput
    & wsl -d LocalDockerHost -e sh -c "ls"
}

Write-Host "Done"










