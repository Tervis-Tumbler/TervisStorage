$TervisStorageArrayInfo = [pscustomobject][ordered]@{
    Name="VNX5200"
    PasswordstateCredentialID = "2574"
    Hostname = "VNX2SPA"
},
[pscustomobject][ordered]@{
    Name="VNX5300"
    PasswordstateCredentialID = "3982"
    Hostname = "VNXSPA"
}

function Get-TervisStorageArrayDetails{
    param(
        [Parameter(Mandatory)][ValidateSet(“VNX5200”,”VNX5300”)][String]$StorageArrayName
    )
    $StorageArrayInfo = $TervisStorageArrayInfo | Where name -EQ $StorageArrayName
    $StorageArrayInfo | Add-Member -MemberType ScriptProperty -Name IPAddress -Value {(Resolve-DnsName -Name $this.Hostname).IPAddress} -Force
    $StorageArrayInfo
}

function Get-LUNSFromVNX {
    param(
        [Parameter(Mandatory)]
        [ValidateSet(“VNX5200”,”VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstateEntryDetails -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID



    $RawGetLUNOutput = Invoke-Command -ScriptBlock {& 'c:\program files\emc\naviseccli.exe' -scope 0 -h $TervisStorageArrayDetails.IPAddress -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password getlun}
    $RawGetLUNOutput | ConvertFrom-String -TemplateFile $PSScriptRoot\VNX_getlun_Template
}   

function Get-SnapshotsFromVNX{
    param(
        [Parameter(Mandatory)]
        [ValidateSet(“VNX5200”,”VNX5300","ALL")]
        $TervisStorageArraySelection
    )
    if($TervisStorageArraySelection -eq "ALL"){
        $SanSelectionList = "vnx5200","vnx5300"
    }
    else{$SanSelectionList = $TervisStorageArraySelection}
    foreach ($Array in $SanSelectionList){
        $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $Array
        $TervisStorageArrayPasswordDetails = Get-PasswordstateEntryDetails -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID
        $RawSnapshotOutput = & 'c:\program files\emc\naviseccli.exe' -scope 0 -h $TervisStorageArrayDetails.IPAddress -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password snap -list
        $RawSnapshotOutput | ConvertFrom-String -TemplateFile $PSScriptRoot\VNX_Snapshotlist_Template
    }
}

function New-VNXLUNSnapshot{
    param(
        [Parameter(Mandatory)]
        $LUNID,

        [Parameter(Mandatory)]
        $SnapshotName,

        [Parameter(Mandatory)]
        [ValidateSet(“VNX5200”,”VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstateCredential -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID -AsPlainText

    $command = "& 'c:\program files\EMC\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) snap -create -res $($LUNID) -name $SnapshotName"
    Invoke-Expression -Command $Command
}

function Mount-VNXSnapshot{
    param(
        [Parameter(Mandatory)]
        $SMPID,

        [Parameter(Mandatory)]
        $SnapshotName,

        [Parameter(Mandatory)]
        [ValidateSet(“VNX5200”,”VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstateCredential -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID -AsPlainText

    $command = "& 'c:\program files\EMC\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) snap -modify -id $snapshotname -allowReadWrite yes"
    Invoke-Expression -Command $Command
    $command = "& 'c:\program files\EMC\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) lun -attach -l $SMPID -snapname $snapshotname"
    Invoke-Expression -Command $Command
    $command = "& 'c:\program files\EMC\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) snap -list -id $snapshotname -detail"
    Invoke-Expression -Command $Command

}

function Dismount-VNXSnapshot{
    param(
        [Parameter(Mandatory)]
        $SMPID,

        [Parameter(Mandatory)]
        [ValidateSet(“VNX5200”,”VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstateCredential -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID -AsPlainText

    $command = "& 'c:\program files\EMC\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) lun -detach -l $SMPID"
    Invoke-Expression -Command $Command
}

