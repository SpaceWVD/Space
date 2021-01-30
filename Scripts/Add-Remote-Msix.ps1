param(
    [string] $SubscriptionId,
    [string] $resourceGroupName,
    [string] $hostpoolName,
    [string] $storage,
    [string] $storagepass,
    [string] $sharename,
    [string] $app1,
    [string] $app2,
    [string] $app3,
    [string] $app4,
    [string] $app5,
    [string] $app6,
    [string] $app7,
    [string] $app8
)

# $ErrorActionPreference = 'Stop'
Connect-AzAccount -Identity

# Import-module az.compute
# Import-module az.resources

if ($null -ne (get-module -name Az.DesktopVirtualization -ListAvailable -ErrorAction SilentlyContinue)) {
    Import-module -name Az.DesktopVirtualization
}
else {
    Install-module -name Az.DesktopVirtualization -force
}


# Checking Apps
$applist = @($app1, $app2, $app3, $app4, $app5, $app6, $app7, $app8) | Where-Object { $_ -ne 'none' } 

$ctx=(Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storage).Context  
$deployedapps=Get-AZStorageFile -Context $ctx -ShareName $sharename  
$deployedapps = $deployedapps.name


foreach ( $app in $applist )
{

    $separators = (" ", ".")
    $appname = $app.split($separators)[2]

    # App Name must have at least 3 chars
    $testlengh = $appname | Measure-Object -Character
    
    if ($testlengh.Characters -lt '3') {
        $appname = $app.split($separators)[2] + $app.split($separators)[3]
    }

    $vhdname = $appname + '.vhd'
    while ($deployedapps -notcontains $vhdname) { Start-sleep -s 15 }
    {
        $uncPath = $fullstorage + '\' + $vhdname
        $obj = Expand-AzWvdMsixImage -HostPoolName $hostpoolName -ResourceGroupName $resourcegroupName -SubscriptionId $SubscriptionId -Uri $uncPath
        New-AzWvdMsixPackage -HostPoolName $hostpoolName -ResourceGroupName $resourcegroupName -SubscriptionId $SubscriptionId -PackageAlias $obj.PackageAlias -DisplayName $appname -ImagePath $uncPath -IsActive:$true
        Get-AzWvdMsixPackage -HostPoolName $hostpoolName -ResourceGroupName $resourcegroupName -SubscriptionId $SubscriptionId | Where-Object { $_.PackageFamilyName -eq $obj.PackageFamilyName }

    }

}


# Shutdown Space Communication
$VMs = get-azvm -ResourceGroupName $resourcegroupName
$VMs.Name | ForEach-Object -ThrottleLimit 100 -Parallel {
        
    Stop-AzVM -ResourceGroupName $resourcegroupName -Name $_. -force

}

ForEach ( $vm in $VMs)
{
    Stop-AzVM -ErrorAction Stop -ResourceGroupName $resourcegroupName -Name $vm -Force

}
