$UiModuleName = "Microsoft.PowerShell.ConsoleGuiTools"

Write-Host "Initialising UI..."

if (!(Get-InstalledModule -Name $UiModuleName -ErrorAction SilentlyContinue))
{
    Write-Host "Installing UI module... This may take a minute. You may need to accept a PSGallery trust prompt."
    Install-Module $UiModuleName
    Write-Host "Done."
}

if(-not([bool]([appdomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.gettypes() -match 'Terminal.Gui.Window' })))
{
    Add-Type -Path (Join-path (Get-InstalledModule -Name Microsoft.PowerShell.ConsoleGuiTools | Select-Object -ExpandProperty InstalledLocation) Terminal.Gui.dll)
}

$App = [Terminal.Gui.Application]
$App::Init()

$UiRoot = $App::Top

$Windows = [Terminal.Gui.Window]
$MainWindow = $Windows::new()

$Buttons = [Terminal.Gui.Button]

$CheckBoxes = [Terminal.Gui.CheckBox]

try 
{
    $MainWindow.Title = "Docker on WSL2 Installer"

    $Button = $Buttons::new()
    $Button.Text = "Exit"
    $Button.add_Clicked(
        {
            $App::RequestStop()
        })
    $MainWindow.Add($Button)
    
    $chk1 = $CheckBoxes::new(10, 10, 10)
    $chk1.Text = "Check 1"
    $MainWindow.Add($chk1)

    $UiRoot.Add($MainWindow)
    $App::Run($UiRoot)

    $App::ShutDown()
}
catch 
{
    Write-Host $_.ScriptStackTrace
    $App::ShutDown()
}

