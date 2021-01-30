Param(
    $storage,
    $storagepass,
    $sharename,
    $projectname,
    $app1,
    $app2,
    $app3,
    $app4,
    $app5,
    $app6,
    $app7,
    $app8 
)

        ##    \ \_____
      ####### [==_____> Space Applications Containerization Program > 
        ##    /_/


& reg add "HKLM\Software\Policies\Microsoft\WindowsStore" /v AutoDownload /t REG_DWORD /d 0 /f
& Schtasks /Change /Tn "\Microsoft\Windows\WindowsUpdate\Automatic app update" /Disable
& Schtasks /Change /Tn "\Microsoft\Windows\WindowsUpdate\Scheduled Start" /Disable
& reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f
& reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Debug" /v ContentDeliveryAllowedOverride /t REG_DWORD /d 0x2 /f
& Set-Content config wuauserv start=disabled


# Manage Space Share & Folders
new-item -path "c:\space\msix" -ItemType Directory
new-item -path "c:\space\vhd" -ItemType Directory
new-item -path "c:\space\cert" -ItemType Directory
new-item -path "c:\space\spaceTools" -ItemType Directory
Start-Transcript "c:\space\appTranscript.txt"


$storageuser = $storage.split('.')[0]
$storageuser = "Azure\" + $storageuser
$fullazureshare = '\\' + $storage + '\' + $sharename
cmd.exe /C "cmdkey /add:$storage /user:$storageuser /pass:$storagepass"
New-PSDrive -Name Z -PSProvider FileSystem -Root $fullazureshare


# spaceTools
$spacefolder = "c:\space\"
$toolsURL = 'https://github.com/SpaceWVD/Space/raw/master/Files/spaceTools.zip'
$toolsZip = "spaceTools.zip"
Invoke-WebRequest -Uri $toolsURL -OutFile "$spacefolder$toolsZip"
Expand-Archive -LiteralPath "c:\space\spaceTools.zip" -DestinationPath "c:\space\spaceTools" -Force -Verbose


# Flying Certificate

# $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("c:\space\spaceTools\cert\cert.pfx","space")
# $rootStore = Get-Item cert:\LocalMachine\Root
# $rootStore.Open("ReadWrite")
# $rootStore.Add($cert)
# $rootStore.Close()


New-SelfSignedCertificate -Type Custom -Subject "CN=$projectname" -KeyUsage DigitalSignature -FriendlyName "$projectname" -CertStoreLocation "Cert:\CurrentUser\my" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") -NotAfter (Get-Date).AddMonths(242)
$password = ConvertTo-SecureString -String space -Force -AsPlainText
Set-Location Cert:\CurrentUser\my
$certThmb = ( Get-ChildItem | Where-Object{$_.Subject -eq "CN=$projectname"} ).Thumbprint
Export-PfxCertificate -cert "Cert:\CurrentUser\my\$certThmb" -FilePath c:\space\cert\cert.pfx -Password $password

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2("c:\space\cert\cert.pfx","space")
$rootStore = Get-Item cert:\LocalMachine\Root
$rootStore.Open("ReadWrite")
$rootStore.Add($cert)
$rootStore.Close()


# Prepare Space Packets Managers
# $DesktopAppInstallerURL = "https://github.com/microsoft/winget-cli/releases/download/v0.2.2941-preview/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle"
# $DesktopAppInstaller = "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle"
# $DesktopAppInstallerPath =  "c:\space\spaceTools\" + $DesktopAppInstaller
# Invoke-WebRequest -Uri $DesktopAppInstallerURL -OutFile $DesktopAppInstallerPath
# Add-AppxPackage "c:\space\spaceTools\Microsoft.VCLibs.140.00_14.0.29231.0.Appx"
# Add-AppxPackage "c:\space\spaceTools\Microsoft.VCLibs.140.00.UWPDesktop_14.0.29231.0.Appx"
# Add-AppxPackage "c:\space\spaceTools\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle"
# Add-AppxPackage "c:\space\spaceTools\Microsoft.MsixPackagingTool_2020.1006.2137.Msix"


# Install Flying Packets Manager
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco feature enable -n allowGlobalConfirmation
choco feature disable -n checksumFiles



        ##    \ \_____
      ####### [==_____> Space MSIX > 
        ##    /_/
        

Set-Location -Path "c:\space\msix"
$applist = @($app1,$app2,$app3,$app4,$app5,$app6,$app7,$app8) | Where-Object { $_ -ne 'none' }

foreach($app in $applist)
{
    $separators = (" ",".")
    $appname = $app.split($separators)[2]

# App Name must have at least 3 chars
    $testlengh = $appname | Measure-Object -Character
    if ($testlengh.Characters -lt '3')
    {
        $appname = $app.split($separators)[2] + $app.split($separators)[3]
    }

    $manifest = $appname + '-manifest.xml'

    '<MsixPackagingToolTemplate
    xmlns="http://schemas.microsoft.com/appx/msixpackagingtool/template/2018"
    xmlns:mptv2="http://schemas.microsoft.com/msix/msixpackagingtool/template/1904">
    <Installer Path="C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" Arguments="' + $app + '"/>
    <SaveLocation PackagePath="C:\space\msix"/>
    <PackageInformation
    PackageName="' + $appname + '"
    PackageDisplayName="' + $appname + '"
    PublisherName="CN=' + $projectname + '"
    PublisherDisplayName="' + $appname + '"
    Version="1.0.0.0">
    </PackageInformation>
    </MsixPackagingToolTemplate>' | Out-File $manifest

    c:\space\spaceTools\MsixPackagingTool\MsixPackagingToolCLI.exe create-package --template $manifest -v
}


# Creating Space MSIX Containers
$allmsix = Get-ChildItem -Path "c:\space\msix" -Filter *.msix | Select-object -ExpandProperty Name 

# $JsonData = @'
# {
#     "apps":  [
#         ]
# }
# '@ | convertfrom-json

foreach($msixName in $allmsix)
{
    $pfxFilePath = "c:\space\cert\cert.pfx"
    $msixPath = "c:\space\msix\" + $msixName
    & "c:\space\spaceTools\signtool.exe" sign /f $pfxFilePath /t "http://timestamp.digicert.com" /p space /fd SHA256 $msixPath


# Create Space App Attach
    $parentFolder = $msixName.split('_')[0]
    $vhdName = $parentFolder + '.vhd'

# Create vhd
    $msixSize = ((Get-Item $msixName).length/1MB)
    [int]$vhdSize = ([int]$msixsize * 4 * 1048576)
    New-VHD -SizeBytes $vhdSize -Path "c:\space\vhd\$vhdName" -Dynamic -Confirm:$false
    $vhdObject = Mount-DiskImage "c:\space\vhd\$vhdName" -Passthru
    $disk = Initialize-Disk -Passthru -Number $vhdObject.Number
    $partition = New-Partition -AssignDriveLetter -UseMaximumSize -DiskNumber $disk.Number
    Format-Volume -FileSystem NTFS -Confirm:$false -DriveLetter $partition.DriveLetter -Force

# Transfering data
    $driveletter = $partition.DriveLetter
    $fullvhdappfolder = $driveletter + ':\' + $parentFolder
    mkdir $fullvhdappfolder

    set-location C:\space\spaceTools\msixmgr
    .\msixmgr.exe -Unpack -packagePath C:\space\msix\$msixName -destination $fullvhdappfolder -applyacls

# Gettings vhd's informations
    $vhdSrc="C:\space\vhd\$vhdName"
    $packageName = (Get-ChildItem -path $fullvhdappfolder).name
    $parentFolderDir = "\" + $parentFolder + "\"
    $volumeGuid = (((get-volume -DriveLetter $driveletter).UniqueId).split('{')[1]).split('}')[0]

    Dismount-DiskImage -Imagepath $vhdSrc
    xcopy.exe C:\space\vhd\$vhdName $fullazureshare

#     $JsonDataAdd = @"
#     {
#         "vhdSrc": "\\\\$storage\\$sharename\\$parentFolder.vhd",
#         "volumeGuid": "$volumeGuid",
#         "packageName": "$packageName",
#         "parentFolder": "$parentFolderDir",
#         "sessionTarget": {
#             "hostPools": [
#                 "Space-Pool"
#             ],
#             "userGroups": [
#                 "$parentFolder-sg"
#             ]
#         }
#     }
# "@ | convertfrom-json

# $JsonData.apps += $JsonDataAdd
}

# $JsonData > "c:\space\vhd\AppAttach.json"

xcopy.exe "c:\space\vhd\AppAttach.json" $fullazureshare
xcopy.exe "c:\space\cert\cert.pfx" $fullazureshare

Stop-Transcript
xcopy.exe "c:\space\appTranscript.txt" $fullazureshare