Param(
    $projectname,
    $storage,
    $storagepass,
    $sharename,
    $app1,
    $app2,
    $app3,
    $app4,
    $app5,
    $app6,
    $app7,
    $app8 
)

Start-Transcript c:\install.log

# Mount Space Share
$storageuser = $storage.split('.')[0]
$storageuser = "Azure\" + $storageuser
$fullazureshare = '\\' + $storage + '\' + $sharename
cmd.exe /C "cmdkey /add:$storage /user:$storageuser /pass:$storagepass"
New-PSDrive -Name Z -PSProvider FileSystem -Root $fullazureshare


# Fly Certificate Verification
$password = ConvertTo-SecureString -String space -Force -AsPlainText
new-item -path "c:\space\cert" -ItemType Directory
New-SelfSignedCertificate -Type "Custom" `
                           -Subject "CN=$projectname" `
                           -KeyUsage "DigitalSignature" `
                           -FriendlyName "$projectname" `
                           -CertStoreLocation "Cert:\CurrentUser\my" `
                           -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
                           -NotAfter (Get-Date).AddMonths(42) `
                           | Export-PfxCertificate -FilePath c:\space\cert\cert.pfx `
                           -Password $password

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("c:\space\cert\cert.pfx","space")
$rootStore = Get-Item cert:\LocalMachine\Root
$rootStore.Open("ReadWrite")
$rootStore.Add($cert)
$rootStore.Close()

xcopy.exe "c:\space\cert\cert.pfx" $fullazureshare


# Sending MSIX Packages Informations
$applist = @($app1,$app2,$app3,$app4,$app5,$app6,$app7,$app8) | Where-Object { $_ -ne 'none' }
$applist | out-file "c:\space\apps.csv"


# Getting spaceMsix
$spaceURL = 'https://raw.githubusercontent.com/David-Ollivier/Space/master/Scripts/spaceMsix.ps1'
Invoke-WebRequest -Uri $spaceURL -OutFile "c:\space\spaceMsix.ps1"
$action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass c:\space\spaceMsix.ps1 -projectname $projectname -storage $storage -storagepass $storagepass -sharename $sharename"
$TaskTrigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -User SYSTEM -Action $action -Trigger $TaskTrigger -TaskName "spaceMsix" -Description "spaceMsix" -Force


# Hyper vSpace Program
DISM /Online /Enable-Feature /All /FeatureName:Microsoft-Hyper-V /NoRestart

Stop-Transcript
Restart-Computer -Force