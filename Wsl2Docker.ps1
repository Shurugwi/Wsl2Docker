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

function DownloadUbuntuImage
{
    $ImageUrl = "https://cloud-images.ubuntu.com/releases/focal/release/ubuntu-20.04-server-cloudimg-amd64-wsl.rootfs.tar.gz"
    $ImageFileName = "$(MyDocumentsFolder)\ubuntu-20.04-server-cloudimg-amd64.tar.gz"

    if(![System.IO.File]::Exists($ImageFileName))
    {
        Write-Host "Downloading Ubuntu 20.04. Be patient, this will take a few minutes..."
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $ImageUrl -OutFile $ImageFileName
    }
    else 
    {
        Write-Host "Ubuntu 20.04 image already exists. $($ImageFilename) Not downloading."
    }    

    return $ImageFileName
}

function MyDocumentsFolder
{
    return [Environment]::GetFolderPath("mydocuments")
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
$ImageFileName = DownloadUbuntuImage
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

    Write-Host "wsl --import LocalDockerHost $($DefaultWslFolder) $($ImageFileName)"
    $wsloutput = & wsl --import LocalDockerHost $DefaultWslFolder $ImageFileName
    $wsloutput
    & wsl -l -v
    & wsl -d LocalDockerHost -e sh -c "echo '185.199.109.133 raw.githubusercontent.com' >> /etc/hosts && exit"

    #From Github
    & wsl -d LocalDockerHost -e sh -c "echo 'Attempting to download installation script...' && echo 'nameserver 8.8.8.8' >> /etc/resolv.conf && wget -q https://raw.githubusercontent.com/Shurugwi/Wsl2Docker/main/InstallDocker.sh -O - | bash && exit"
    
    #Local Dev
    #& wsl -d LocalDockerHost -e sh -c "echo 'Attempting to download installation script...' && cp /mnt/d/Projects2021/Wsl2Docker/InstallDocker.sh ~/id.sh && tr -d '\15\32' < ~/id.sh > ~/id2.sh && chmod +x ~/id2.sh && bash ~/id2.sh && exit"
}

Write-Host "Done"


 

 





