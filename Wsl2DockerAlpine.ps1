# This script needs to run with elevated privileges as it needs to make system changes.
# ExecutionPolicy must be set to run sctipts. At least for the current user.
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned
# or
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser



$DefaultWslFolder = "c:\Wsl"
$EnableWsl2KernelTempFile = $env:TEMP + "\enablewsl2kernel.tmp"

function RebootPending {
    if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
    if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
    if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
    try { 
        $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
        $status = $util.DetermineIfRebootPending()
        if (($null -ne $status) -and $status.RebootPending) {
            #return $true Disable
            return $false
        }
    }
    catch { }

    return $false
}

function MyDocumentsFolder
{
    return [Environment]::GetFolderPath("mydocuments")
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

    $AlpineImageFileName = "$(MyDocumentsFolder)\AlpineImage$($AlpineVersion).tar.gz"

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

function EnsureWsl2Kernel
{
    if(![System.IO.File]::Exists($EnableWsl2KernelTempFile))
    {
        return
    }

    #$KernelUpdateUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
    $KernelUpdateUrl = "https://github.com/Shurugwi/Wsl2Docker/raw/main/wsl_update_x64.msi"

    $KernelUpdateMsi = "$(MyDocumentsFolder)\wsl_update_x64.msi"

    if(![System.IO.File]::Exists($KernelUpdateMsi))
    {
        Write-Host "Downloading WSL2 Kernel update"
        Invoke-WebRequest -Uri $KernelUpdateUrl -OutFile $KernelUpdateMsi
        Write-Host "Installing WSL2 kernel update"
        #$KernelUpdateMsi
        #& $KernelUpdateMsi /nq
        Start-Process -Wait -FilePath $KernelUpdateMsi -ArgumentList "/qn"
        & wsl --shutdown
        Write-Host (& wsl --set-default-version 2)
    }

    if([System.IO.File]::Exists($EnableWsl2KernelTempFile))
    {
        [System.IO.File]::Delete($EnableWsl2KernelTempFile)
    }

    Write-Host "WSL2 Kernel updated. Please restart the script to continue"
    exit
}


#if(RebootPending)
#{
#    Write-Host "Your computer needs to be restarted before running this script again."
#    exit
#}

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

#Enable HyperV if needed
if((Get-WindowsOptionalFeature -Online -FeatureName:VirtualMachinePlatform).State -eq "Disabled")
{
    Write-Host "HyperV needs to be enabled"
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    $NeedsPcRestart = $true
    Write-Host "HyperV has been enabled. This will be completed after a restart."
}

if($NeedsPcRestart)
{
    if(![System.IO.File]::Exists($EnableWsl2KernelTempFile))
    {
        [System.IO.File]::Create($EnableWsl2KernelTempFile)
    }
    Write-Host "Your computer needs to be restarted before wsl can be used."
    Restart-Computer -Confirm
    exit
}

EnsureWsl2Kernel
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
    #& wsl --set-default-version 1
    #& sc stop cmservice
    #& sc stop hns
    #& sc stop vmcompute
    #& sc stop lxssmanager
    #& sc start cmservice
    #& sc start hns
    #& sc start vmcompute
    #& sc start lxssmanager    
    Write-Host "Creating WSL docker environment. This may take a few minutes..."

    $DockerHostFolder = "$($DefaultWslFolder)\LocalDockerHost\"

    if(![System.IO.Directory]::Exists($DefaultWslFolder))
    {
        [System.IO.Directory]::CreateDirectory($DefaultWslFolder)
        [System.IO.Directory]::CreateDirectory($DockerHostFolder)
    }

    $wsloutput = & wsl --import LocalDockerHost $DefaultWslFolder $AlpineImageFileName
    $wsloutput
    & wsl -l -v
    & wsl -d LocalDockerHost -e sh -c "echo '185.199.109.133 raw.githubusercontent.com' >> /etc/hosts && exit"
    & wsl -d LocalDockerHost -e sh -c "echo 'Attempting to download installation script...' && echo 'nameserver 8.8.8.8' >> /etc/resolv.conf && wget -q https://raw.githubusercontent.com/Shurugwi/Wsl2Docker/main/InstallDockerAlpine.sh -O - | ash && exit"
}

Write-Host "Done"


 

 





