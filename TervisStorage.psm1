$TervisStorageArrayInfo = [pscustomobject][ordered]@{
    Name="VNX5200"
    PasswordstateCredentialID = "2574"
    Hostname = "VNX2SPA"
},
[pscustomobject][ordered]@{
    Name="VNX5300"
    PasswordstateCredentialID = "6446"
    Hostname = "VNXSPA"
}

$TervisBrocadeSwitchDefinitions = [pscustomobject][ordered]@{
    Name="BrocadeSW1"
    PasswordstateCredentialID = "44"
    Fabric = "FabricA"
    InitiatorSuffix = "FC0"
    Site = "HQ"
},
[pscustomobject][ordered]@{
    Name="BrocadeSW2"
    PasswordstateCredentialID = "45"
    Fabric = "FabricB"
    InitiatorSuffix = "FC1"
    Site = "HQ"
}

$TervisStorageZoningTargets = [psobject][ordered]@{
    Array = "VNX5300" 
    Initiators = [psobject][ordered]@{
        Name = "FabricA"
        Targets = "VNX1_A2;VNX1_B2"
    },
    [psobject][ordered]@{
        Name = "FabricB"
        Targets = "VNX1_A3;VNX1_B3"
    }
},
[psobject][ordered]@{
    Array = "VNX5200"
    Initiators = [psobject][ordered]@{
        Name = "FabricA"
        Targets = "VNX2_A2_P0;VNX2_A2_P1;VNX2_B2_P0;VNX2_B2_P1"
    },
    [psobject][ordered]@{
        Name = "FabricB"
        Targets = "VNX2_A2_P2;VNX2_A2_P3;VNX2_B2_P2;VNX2_B2_P3"
    }
},
[psobject][ordered]@{
    Array = "CX3-20"
    Initiators = [psobject][ordered]@{
        Name = "FabricA"
        Targets = "Yosemite_SAN_A0;Yosemite_SAN_B1"
    },
    [psobject][ordered]@{
        Name = "FabricB"
        Targets = "Yosemite_SAN_A1;Yosemite_SAN_B0"
    }
},
[psobject][ordered]@{
    Array = "MD3860F-HQ"
    Initiators = [psobject][ordered]@{
        Name = "FabricA"
        Targets = "MD3860F_SP0_P0;MD3860F_SP1_P0"
    },
    [psobject][ordered]@{
        Name = "FabricB"
        Targets = "MD3860F_SP0_P1;MD3860F_SP1_P1"
    }
},
[psobject][ordered]@{
    Array = "MD3860F-P10"
    Initiators = [psobject][ordered]@{
        Name = "FabricA"
        Targets = "MD3860F02_SP0_P0;MD3860F_P10_SP1_P0"
    },
    [psobject][ordered]@{
        Name = "FabricB"
        Targets = "MD3860F02_SP0_P1;MD3860F_P10_SP1_P1"
    }
}

function Get-TervisStorageZoningTargets{
    param(
        #[Parameter()][ValidateSet("BrocadeSW1","BrocadeSW2")][String]$BrocadeSwitch
        $Array,
        $Fabric
    )
    if($Array -eq "All"){
        $TervisStorageZoningTarget = $TervisStorageZoningTargets
    }
    else{
        $TervisStorageZoningTarget = $TervisStorageZoningTargets | where Array -eq $Array
    }
    
    $TervisStorageZoningTarget.initiators | where {-not $Fabric -or $_.name -In $Fabric}
}

function Get-TervisStorageArrayDetails{
    param(
        [Parameter(Mandatory)][ValidateSet("VNX5200","VNX5300")][String]$StorageArrayName,
        [Parameter()][ValidateSet("SPA","SPB")][string]$StorageProcessor = "SPA"
#        $StorageProcessor = "SPA"
    )
    $StorageArrayInfo = $TervisStorageArrayInfo | Where name -EQ $StorageArrayName
    $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $StorageArrayInfo.PasswordstateCredentialID
    if ($StorageProcessor -eq "SPA") {$SPIPAddress = $TervisStorageArrayPasswordDetails.GenericField1}
    if ($StorageProcessor -eq "SPB") {$SPIPAddress = $TervisStorageArrayPasswordDetails.GenericField2}

    $StorageArrayInfo | Add-Member -MemberType ScriptProperty -Name IPAddress -Value {(Resolve-DnsName -Name $this.Hostname).IPAddress} -Force
    $StorageArrayInfo | Add-Member -MemberType NoteProperty -Name SPIPAddress -Value $SPIPAddress -Force
    $StorageArrayInfo

}

function Get-TervisBrocadeDetails{
    param(
        [Parameter()][ValidateSet("BrocadeSW1","BrocadeSW2")][String]$BrocadeSwitch
    )
    if($BrocadeSwitch){
        $SwitchDefinition = $TervisBrocadeSwitchDefinitions| Where name -EQ $BrocadeSwitch
    }
    else{$SwitchDefinition = $TervisBrocadeSwitchDefinitions}
    $SwitchDefinition | Add-Member -MemberType ScriptProperty -Name IPAddress -Value {(Resolve-DnsName -Name $this.Name).IPAddress} -Force
    $SwitchDefinition
}

function Get-VNXFileList {
    param (
        [Parameter(Mandatory)][ValidateSet("VNX5200","VNX5300")][String]$StorageArrayName,
        [Parameter(Mandatory)][ValidateSet("SPA","SPB")]$StorageProcessor,
        [Switch]$Today
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $StorageArrayName -StorageProcessor $StorageProcessor
    $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID
    $RawGetFileListOutput = & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $($TervisStorageArrayDetails.SPIPAddress) -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) managefiles -list
    $SPFileList = $RawGetFileListOutput | ConvertFrom-String -TemplateFile $PSScriptRoot\VNX_GetFileList_Template
    if ($Today) {
        $SPFileList | Where-Object Timestamp -ge (get-date).AddDays(-1) | Sort-Object -Property timestamp -Descending
    }
    else { $SPFileList | Sort-Object -Property timestamp -Descending }
}

function invoke-GenerateVNXSPCollect {
    param (
        [Parameter(Mandatory)][ValidateSet("VNX5200","VNX5300")][String]$StorageArrayName,
        [Parameter(Mandatory)][ValidateSet("SPA","SPB")]$StorageProcessor
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $StorageArrayName -StorageProcessor $StorageProcessor
    $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID

    Invoke-Command -ScriptBlock {& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $($TervisStorageArrayDetails.SPIPAddress) -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) spcollect}
#    & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayPasswordDetails.GenericField2 -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password naviseccli spcollect
}

function Get-VNXArrayFaults {
    param (
        [Parameter(Mandatory)][ValidateSet("VNX5200","VNX5300")][String]$StorageArrayName,
        [Parameter(Mandatory)][ValidateSet("SPA","SPB")]$StorageProcessor
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $StorageArrayName    
    $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID

    Invoke-Command -ScriptBlock {& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $($TervisStorageArrayDetails.SPIPAddress) -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -faults -list}
#    & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayPasswordDetails.GenericField2 -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password spcollect
}

function Get-SPLogFilesFromVNX{
    param (
        [Parameter(Mandatory)][ValidateSet("VNX5200","VNX5300","All")][String]$StorageArrayName,
        [Parameter(Mandatory)][ValidateSet("SPA","SPB")]$StorageProcessor,
        [Parameter(Mandatory)]$FileName,
        [Parameter(Mandatory)]$DestinationPath
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $StorageArrayName -StorageProcessor $StorageProcessor
    $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID

    Invoke-Command -ScriptBlock {& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $($TervisStorageArrayDetails.SPIPAddress) -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) managefiles -retrieve -path $DestinationPath -file $FileName -o}
#    & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayPasswordDetails.GenericField2 -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password spcollect
}

function Get-LUNSFromVNX {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("VNX5200","VNX5300","All")]
        $TervisStorageArraySelection
    )

    if($TervisStorageArraySelection -eq "ALL"){
        $SanSelectionList = "vnx5200","vnx5300"
    }
    else{$SanSelectionList = $TervisStorageArraySelection}
    foreach ($Array in $SanSelectionList){
        $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $Array
        $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID
        $RawGetLUNOutput = Invoke-Command -ScriptBlock {& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayDetails.IPAddress -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password getlun}
        $LUNOutput = $RawGetLUNOutput | ConvertFrom-String -TemplateFile $PSScriptRoot\VNX_getlun_Template
        $LUNOutput | Add-Member -MemberType NoteProperty -name "Array" -PassThru -Value $Array
    }
}   

function Get-SnapshotsFromVNX{
    param(
        [Parameter(Mandatory)]
        [ValidateSet("VNX5200","VNX5300","ALL")]
        $TervisStorageArraySelection
    )
    if($TervisStorageArraySelection -eq "ALL"){
        $SanSelectionList = "vnx5200","vnx5300"
    }
    else{$SanSelectionList = $TervisStorageArraySelection}
    foreach ($Array in $SanSelectionList){
        $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $Array
        $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID
        $RawSnapshotOutput = & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayDetails.IPAddress -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password snap -list
        $SnapshotOutput = $RawSnapshotOutput | ConvertFrom-String -TemplateFile $PSScriptRoot\VNX_Snapshotlist_Template
        $SnapshotOutput | Add-Member -MemberType NoteProperty -name "Array" -PassThru -Value $Array

    }
}

function Get-StorageGroupsFromVNX{
    param(
        [Parameter(Mandatory)]
        [ValidateSet("VNX5200","VNX5300","ALL")]
        $TervisStorageArraySelection
    )
    if($TervisStorageArraySelection -eq "ALL"){
        $SanSelectionList = "vnx5200","vnx5300"
    }
    else{$SanSelectionList = $TervisStorageArraySelection}
    foreach ($Array in $SanSelectionList){
        $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $Array
        $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID
        $RawStorageGroupOutput = & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayDetails.IPAddress -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password storagegroup -list
        $output = $RawStorageGroupOutput | ConvertFrom-String -TemplateFile $PSScriptRoot\VNX_StorageGroup_Template.txt
        $LunsFromVNX = Get-LUNSFromVNX -TervisStorageArraySelection $Array
        Foreach ($Storagegroup in $output){
            $StorageGroupName = $StorageGroup.StorageGroupName
            if(-not $StorageGroup.LUNS){
                [pscustomobject][ordered]@{
                    StorageGroupName = $StorageGroupName
                    Array = $Array
                    MemberLUNs = ""
                }
                Continue
            }
            $StorageGroupName = $StorageGroup.StorageGroupName
            $MemberLuns = @()
            ($Storagegroup.luns).items | %{
                $LUNDetail = $LunsFromVNX | where LUNID -eq $_.ALUNumber
                $MemberLuns += [pscustomobject][ordered]@{
                    HLUNumber = $_.HLUNumber
                    ALUNumber = $_.ALUNumber
                    Name = $LUNDetail.LUNNAME
                    "Capacity GB" = (($LUNDetail.LUNCapacity) / 1KB)
                    LUNUID = $LUNDetail.LUNUID
                }
            }
            [pscustomobject][ordered]@{
                StorageGroupName = $StorageGroupName
                Array = $Array
                MemberLUNs = $MemberLuns
            }
        }
    }
}

function New-VNXLUNSnapshot{
    param(
        [Parameter(Mandatory)]
        $LUNID,

        [Parameter(Mandatory)]
        $SnapshotName,

        [Parameter(Mandatory)]
        [ValidateSet("VNX5200","VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID

    $command = "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) snap -create -res $($LUNID) -name '$SnapshotName'"
    Invoke-Expression -Command $Command
}

function Copy-VNXLUNSnapshot{
    param(
        [Parameter(Mandatory)]
        $SnapshotName,

        [Parameter(Mandatory)]
        $SnapshotCopyName,

        [Parameter(Mandatory)]
        [ValidateSet("VNX5200","VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID

    $command = "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) snap -copy -id $SnapshotName -name $SnapshotCopyName"
    Invoke-Expression -Command $Command
}

function Mount-VNXSnapshot{
    param(
        [Parameter(Mandatory)]
        $SMPID,

        [Parameter(Mandatory)]
        $SnapshotName,

        [Parameter(Mandatory)]
        [ValidateSet("VNX5200","VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID

    $command = "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) snap -modify -id $snapshotname -allowReadWrite yes"
    Invoke-Expression -Command $Command
    $command = "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) lun -attach -l $SMPID -snapname $snapshotname"
    Invoke-Expression -Command $Command
    $command = "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) snap -list -id $snapshotname -detail"
    Invoke-Expression -Command $Command

}

function Dismount-VNXSnapshot{
    param(
        [Parameter(Mandatory)]
        $SMPID,

        [Parameter(Mandatory)]
        [ValidateSet("VNX5200","VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID

    $command = "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) lun -detach -l $SMPID"
    Invoke-Expression -Command $Command
}

function Get-VMWWN {
  <#
  .SYNOPSIS
   Get WWNs for VM Virtual Fiber Channel adapters properly formatted for initiator entry.
  .DESCRIPTION
  When adding virtual fiber channel adapters in a VM, it is necessary to manually zone and manually add initiators to the VNX. This function will get Set A and Set B WWNs for a VM and reformat so it can be used in zonine and EMC initiator list.
  .EXAMPLE
  Get-VMWWN TestVM
  Retrieves initiator information for Hyper-V guest TestVM and outputs to stdout.
  .EXAMPLE
  Get-VMWWN TestVM | Register-UnisphereHost -SanSelection VNX2
  Retrieves initiator information for Hyper-V guest TestVM. Output is piped into Register-UnisphereHost to create storage group and register initiators on the VNX5200.
  .PARAMETER VMName
  The target VM name to get WWNs from.
  .PARAMETER ClusterName
  The name of the cluster in which the target VM lives.
  #>

  param
  (
  [Parameter(Mandatory=$true)]
  [string] $VMName,
  [string] $ClusterName = "hypervcluster5"
  )

  $VMName = $VMName.ToUpper()
  $ClusterNode = Get-ClusterGroup -Cluster $ClusterName -Name $VMName | select ownernode

  $VMFabricA = Get-VMFibreChannelHba -VMName $VMName -ComputerName $ClusterNode.OwnerNode | where SanName -eq "FabricA"
  $VMFabricB = Get-VMFibreChannelHba -VMName $VMName -ComputerName $ClusterNode.OwnerNode | where SanName -eq "FabricB"

  $FabricAWWNs = ($VMFabricA.WorldWideNodeNameSetA + $VMFabricA.WorldWidePortNameSetA), ($VMFabricA.WorldWideNodeNameSetB + $VMFabricA.WorldWidePortNameSetB)
  $FabricBWWNs = ($VMFabricB.WorldWideNodeNameSetA + $VMFabricB.WorldWidePortNameSetA), ($VMFabricB.WorldWideNodeNameSetB + $VMFabricB.WorldWidePortNameSetB)



    $FabricAWWNSetA = (&{for ($i = 0;$i -lt 32;$i += 2)
     {
       $FabricAWWNs[0].substring($i,2)
     }}) -join ":"
     $FabricAWWNNA = $FabricAWWNSetA.substring(0,23)
     $FabricAWWPNA = $FabricAWWNSetA.substring(24,23)

    $FabricAWWNSetB = (&{for ($i = 0;$i -lt 32;$i += 2)
     {
       $FabricAWWNs[1].substring($i,2)
     }}) -join ":"
     $FabricAWWNNB = $FabricAWWNSetB.substring(0,23)
     $FabricAWWPNB = $FabricAWWNSetB.substring(24,23)
     
    $FabricBWWNSetA = (&{for ($i = 0;$i -lt 32;$i += 2)
     {
       $FabricBWWNs[0].substring($i,2)
     }}) -join ":"
     $FabricBWWNNA = $FabricBWWNSetA.substring(0,23)
     $FabricBWWPNA = $FabricBWWNSetA.substring(24,23)

    $FabricBWWNSetB = (&{for ($i = 0;$i -lt 32;$i += 2)
     {
       $FabricBWWNs[1].substring($i,2)
     }}) -join ":"
     $FabricBWWNNB = $FabricBWWNSetB.substring(0,23)
     $FabricBWWPNB = $FabricBWWNSetB.substring(24,23)
 
    $FabricDetail = New-Object psobject
        $FabricDetail | Add-Member Hostname $VMName.ToUpper()
        $FabricDetail | Add-Member FabricAWWNSetA ($fabricAWWNNA + ":" + $FabricAWWPNA)
        $FabricDetail | Add-Member FabricAWWNNSetA $fabricAWWNNA
        $FabricDetail | Add-Member FabricAWWPNSetA $FabricAWWPNA
        $FabricDetail | Add-Member FabricAWWNSetB ($fabricAWWNNB + ":" + $FabricAWWPNB)
        $FabricDetail | Add-Member FabricAWWNNSetB $fabricAWWNNB
        $FabricDetail | Add-Member FabricAWWPNSetB $FabricAWWPNB
        $FabricDetail | Add-Member FabricBWWNSetA ($fabricBWWNNA + ":" + $FabricBWWPNA)
        $FabricDetail | Add-Member FabricBWWNNSetA $fabricBWWNNA
        $FabricDetail | Add-Member FabricBWWPNSetA $FabricBWWPNA
        $FabricDetail | Add-Member FabricBWWNSetB ($fabricBWWNNB + ":" + $FabricBWWPNB)
        $FabricDetail | Add-Member FabricBWWNNSetB $fabricBWWNNB
        $FabricDetail | Add-Member FabricBWWPNSetB $FabricBWWPNB


Write-Output $FabricDetail

}

function Register-UnisphereHost{
      param
      (
      [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $FabricDetail,

        [Parameter(Mandatory=$true)]
        [ValidateSet('VNX5300','VNX2','ALL')]
        $SANSelection,

        [Parameter(Mandatory=$true)]
        [string]$IPAddress,

        [switch]$ScriptOnly
    
      )
    if (!(Test-Path 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe'))
        {
        write-host "NaviSecCLI.exe not found. Please install NaviSECCLI and try again."
        break
        }
#        $SANDetail = New-Object psobject
        $SANDetail = @()
    if (($SANSelection -eq "VNX5300") -or ($SANSelection -eq "ALL")){
        $SANDetail += [PSCustomObject][Ordered]@{
            Name = "VNX5300"
            PortListA = @( ("a","0"),("b","0"))
            PortListB = @( ("a","1"),("b","1"))
            SPIP = "10.172.248.153"
        }
    }
    if (($SANSelection -eq "VNX5200") -or ($SANSelection -eq "ALL") ){
        $SANDetail += [PSCustomObject][Ordered]@{
            Name = "VNX5200"
            PortListA = @( ("a","0"),("a","1"),("b","0"),("b","1") )
            PortListB = @( ("a","2"),("a","3"),("b","2"),("b","3") )
            SPIP = "10.172.248.160"
        }
    }

    if($SANSelection -eq "ALL"){
        $SanSelectionList = "vnx5200","vnx5300"
    }
    else{$SanSelectionList = $TervisStorageArraySelection}
    
        if($FabricDetail.FabricAWWNSetB)
            {
                $WWNListA = ($FabricDetail.FabricAWWNSetA,$FabricDetail.FabricAWWNSetB)
                $WWNListB = ($FabricDetail.FabricBWWNSetA,$FabricDetail.FabricBWWNSetB)
            }
        Else
            {
                $WWNListA = $FabricDetail.FabricAWWNSetA
                $WWNListB = $FabricDetail.FabricBWWNSetA
            }
    

    $Command = ""
    foreach ($Array in $SANDetail){
        $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $Array.Name
        $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $($TervisStorageArrayDetails.PasswordstateCredentialID)
        write-host "`nCreating Storage Groups`n"
        $command += "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) storagegroup -create -gname $($FabricDetail.Hostname) ; `n"
    
        Foreach ($WWN in $WWNListA)
            {
            Foreach($Port in $Array.PortListA)
                {
                $command += "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) storagegroup -setpath -o -gname " `
                + $FabricDetail.Hostname + `
                " -hbauid "+ $WWN + `
                " -sp " + $Port[0] + `
                " -spport " + $Port[1] + `
                " -type 3 -ip " + $IPAddress + " -host " + $FabricDetail.Hostname + " -failovermode 4 -arraycommpath 1 ; `n"
                }
            }
        
        Foreach ($WWN in $WWNListB)
            {
            Foreach($Port in $Array.PortListB)
                {
                $command += "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) storagegroup -setpath -o -gname " `
                + $FabricDetail.Hostname + `
                " -hbauid "+ $WWN + `
                " -sp " + $Port[0] + `
                " -spport " + $Port[1] + `
                " -type 3 -ip " + $IPAddress + " -host " + $FabricDetail.Hostname + " -failovermode 4 -arraycommpath 1 ; `n"
                }
            }
    }
    write-host "`nRegistering initiators with selected SANs`n"
    if($scriptonly){
        write-host $Command
    }
    else{
        Invoke-Expression -Command $Command
    }
}

function Set-BrocadeZoning {
    [CmdletBinding()]
      param
      (
    [Parameter(Mandatory, ValueFromPipeline)]$FabricDetail,
    [Parameter(Mandatory)][ValidateSet('VNX5300','VNX2','MD3860F01','MD3860F02','VNX-ALL','ALL')]$SANSelection
      )
    $BrocadeSW1Credential = Get-PasswordstatePassword -AsCredential -ID 44
    $BrocadeSW2Credential = Get-PasswordstatePassword -AsCredential -ID 45
    if($FabricDetail.FabricAWWNSetB)
    {
        $InitiatorAWWN = ($FabricDetail.FabricAWWPNSetA + ";" + $FabricDetail.fabricAWWPNSetB)
        $InitiatorBWWN = ($FabricDetail.FabricBWWPNSetA + ";" + $FabricDetail.FabricBWWPNSetB)
    }
    Else
    {
        $InitiatorAWWN = ($FabricDetail.FabricAWWPNSetA)
        $InitiatorBWWN = ($FabricDetail.FabricBWWPNSetA)
    }
    switch ($SanSelection)
        {
            "VNX-ALL" {
                $TargetInitiatorA = "VNX1_A2;VNX1_B2;VNX2_A2_P0;VNX2_A2_P1;VNX2_B2_P0;VNX2_B2_P1"
                $TargetInitiatorB = "VNX1_A3;VNX1_B3;VNX2_A2_P2;VNX2_A2_P3;VNX2_B2_P2;VNX2_B2_P3"
            }
            "VNX5300" {
                $TargetInitiatorA = "VNX1_A2;VNX1_B2"
                $TargetInitiatorB = "VNX1_A3;VNX1_B3"
            }
            "VNX2" {
                $TargetInitiatorA = "VNX2_A2_P0;VNX2_A2_P1;VNX2_B2_P0;VNX2_B2_P1"
                $TargetInitiatorB = "VNX2_A2_P2;VNX2_A2_P3;VNX2_B2_P2;VNX2_B2_P3"
            }
            "ALL" {
                $TargetInitiatorA = "VNX2_A2_P0;VNX2_A2_P1;VNX2_B2_P0;VNX2_B2_P1;VNX1_A2;VNX1_B2;MD3860F_SP0_P0;MD3860F_SP1_P0;MD3860F02_SP0_P0;MD3860F02_SP1_P0"
                $TargetInitiatorB = "VNX2_A2_P2;VNX2_A2_P3;VNX2_B2_P2;VNX2_B2_P3;VNX1_A3;VNX1_B3;MD3860F_SP0_P1;MD3860F_SP1_P1;MD3860F02_SP0_P1;MD3860F02_SP1_P1"
            }
            "MD3860F01" {
                $TargetInitiatorA = "MD3860F_SP0_P0;MD3860F_SP1_P0"
                $TargetInitiatorB = "MD3860F_SP0_P1;MD3860F_SP1_P1"
            }
            "MD3860F02" {
                $TargetInitiatorA = "MD3860F02_SP0_P0;MD3860F02_SP1_P0"
                $TargetInitiatorB = "MD3860F02_SP0_P1;MD3860F02_SP1_P1"
            }

        }

    $FabricDetail.Hostname = $FabricDetail.Hostname -replace "-",""

    $ConfigMemberA = New-Object psobject
    $ConfigMemberA | Add-Member InitiatorAName $FabricDetail.Hostname
    $ConfigMemberA | Add-Member InitiatorAWWN $InitiatorAWWN
    $ConfigMemberA | Add-Member AliasNameA (($FabricDetail.Hostname).ToUpper() + "_FC0")
    $ConfigMemberA | Add-Member ZoneNameA ($FabricDetail.Hostname + "_TO_SANS").ToUpper()
    $ConfigMemberA | Add-Member ZoneTargetsA $TargetInitiatorA
    
    $ConfigMemberB = New-Object psobject
    $ConfigMemberB | Add-Member InitiatorBName $FabricDetail.Hostname
    $ConfigMemberB | Add-Member InitiatorBWWN $InitiatorBWWN
    $ConfigMemberB | Add-Member AliasNameB (($FabricDetail.Hostname).ToUpper() + "_FC1")
    $ConfigMemberB | Add-Member ZoneNameB ($FabricDetail.Hostname + "_TO_SANS").ToUpper()
    $ConfigMemberB | Add-Member ZoneTargetsB $TargetInitiatorB
    
#    $SSHCommand = "" 
    
    $FabricASSHScript += "alicreate `'$($ConfigMemberA.AliasNameA)`', `'$($ConfigMemberA.InitiatorAWWN)`' ;`n"
    $ConfigMemberA.ZoneTargetsA -split ";" | %{$FabricASSHScript += "zonecreate $($ConfigMemberA.AliasNameA)_TO_$($_), `'$($ConfigMemberA.AliasNameA);$($_)`' ;`n"}
    $ConfigMemberA.ZoneTargetsA -split ";" | %{$FabricASSHScript += "cfgadd cfg, $($ConfigMemberA.AliasNameA)_TO_$($_);`n"}
    $FabricASSHScript += "echo `'y`' | cfgsave ; echo `'y`' | cfgenable cfg`n"
    #write-host "`nBrocadeSW1 Zoning Script"
    #write-host "********************************************************"
#    $FabricASSHScript
    #write-host "********************************************************"
    #Write-Host ""

#    $SSHCommand = ""     
    $FabricBSSHScript += "alicreate `'$($ConfigMemberB.AliasNameB)`', `'$($ConfigMemberB.InitiatorBWWN)`' ;`n"
    $ConfigMemberB.ZoneTargetsB -split ";" | %{$FabricBSSHScript += "zonecreate $($ConfigMemberB.AliasNameB)_TO_$($_), `'$($ConfigMemberB.AliasNameB);$($_)`' ;`n"}
    $ConfigMemberB.ZoneTargetsB -split ";" | %{$FabricBSSHScript += "cfgadd cfg, $($ConfigMemberB.AliasNameB)_TO_$($_);`n"}
    $FabricBSSHScript += "echo `'y`' | cfgsave ; echo `'y`' | cfgenable cfg`n"
    #write-host "BrocadeSW2 Zoning Script"
    #write-host "********************************************************"
#    $FabricBSSHScript
    #write-host "********************************************************"
    #Write-Host ""
#    $SSHCommand = "" 

$FabricASSHScript
$FabricBSSHScript

#    New-SSHSession -ComputerName brocadesw1 -Credential $BrocadeSW1Credential -AcceptKey
#    Invoke-SSHCommand -SSHSession (Get-SSHSession) -Command $FabricASSHScript
#    get-sshsession | Remove-SSHSession
#    New-SSHSession -ComputerName brocadesw2 -Credential $BrocadeSW1Credential -AcceptKey
#    Invoke-SSHCommand -SSHSession (Get-SSHSession) -Command $FabricBSSHScript
#    Get-SSHSession | Remove-SSHSession
#    $FabricBSSHScript    
}

function Invoke-ClaimMPOI {
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
    )
    Process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $MSDSMList = Get-MSDSMSupportedHW
            if (-NOT ($MSDSMList | Where {$_.VendorId -eq "DGC" -and $_.ProductId -eq "Raid 3"})) {
                New-MSDSMSupportedHW -VendorId DGC -ProductId "Raid 3"
            }
            if (-NOT ($MSDSMList | Where {$_.VendorId -eq "DGC" -and $_.ProductId -eq "Raid 5"})) {
                New-MSDSMSupportedHW -VendorId DGC -ProductId "Raid 5"
            }
            if (-NOT ($MSDSMList | Where {$_.VendorId -eq "DGC" -and $_.ProductId -eq "Raid 1"})) {
                New-MSDSMSupportedHW -VendorId DGC -ProductId "Raid 1"
            }
            if (-NOT ($MSDSMList | Where {$_.VendorId -eq "DGC" -and $_.ProductId -eq "Raid 0"})) {
                New-MSDSMSupportedHW -VendorId DGC -ProductId "Raid 0"
            }
            if (-NOT ($MSDSMList | Where {$_.VendorId -eq "DGC" -and $_.ProductId -eq "Raid 10"})) {
                New-MSDSMSupportedHW -VendorId DGC -ProductId "Raid 10"
            }
            if (-NOT ($MSDSMList | Where {$_.VendorId -eq "DGC" -and $_.ProductId -eq "VRAID"})) {
                New-MSDSMSupportedHW -VendorId DGC -ProductId VRAID
            }
            if (-NOT ($MSDSMList | Where {$_.VendorId -eq "DGC" -and $_.ProductId -eq "DISK"})) {
                New-MSDSMSupportedHW -VendorId DGC -ProductId DISK
            }
            if (-NOT ($MSDSMList | Where {$_.VendorId -eq "DGC" -and $_.ProductId -eq "LUNZ"})) {
                New-MSDSMSupportedHW -VendorId DGC -ProductId LUNZ
            }
            if (-NOT ($MSDSMList | Where {$_.VendorId -eq "DELL" -and $_.ProductId -eq "MD38xxf"})) {
                New-MSDSMSupportedHW -VendorId DELL -ProductId MD38xxf
            }
            if (-NOT ($MSDSMList | Where {$_.VendorId -eq "DELL" -and $_.ProductId -eq "Universal Xport"})) {
                New-MSDSMSupportedHW -VendorId DELL -ProductId "Universal Xport"
            }
            $SupportedHardware = Get-MPIOAvailableHW  | Where {($_.IsMultipathed -eq $false) -AND ($_.VendorId -ne "Msft") -and ($_.ProductId -ne "Virtual Disk")}
            if ($SupportedHardware) {
                Update-MPIOClaimedHW
                Restart-Computer
                Wait-ForNodeRestart -ComputerName $ComputerName
            }
        }    
    }
}

function Remove-BrocadeZoning {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact="High"
    )]
    param(
        [parameter(Mandatory,ValueFromPipeline)]$VM,
        [switch]$ScriptOnly
        
#        [Parameter(Mandatory)]$Hostname,          
#       
#        [Parameter(Mandatory)]
#        [ValidateSet('VNX5300','VNX2','CX3-20','MD3860F-HQ','MD3860F-P10','ALL')]$SANSelection
    )
    begin {
    $TervisBrocadeDetails = Get-TervisBrocadeDetails
    }
    Process {
        $Computername = $VM.VMName -replace "-",""
        foreach ($Switch in $TervisBrocadeDetails){
            $ZoningTargetList = Get-TervisStorageZoningTargets -Array All -Fabric $Switch.Fabric
            $TervisBrocadePasswordstateCredential = Get-PasswordstatePassword -AsCredential -ID $Switch.PasswordstateCredentialID
            New-SSHSession -ComputerName $Switch.IPAddress -Credential $TervisBrocadePasswordstateCredential
#            foreach ($Array in $SANSelection){
#                $ZoningTargetList = Get-TervisStorageZoningTargets -Array $Array -Fabric $Switch.Fabric
                $AliasName = ("$($Computername.ToUpper())_$($Switch.InitiatorSuffix)")
                $ZoningTargets = $ZoningTargetList.targets -split ";"
                $SSHCommand = ""
                $ZoningTargets | %{$SSHCommand += "cfgremove `"cfg`", `"$($AliasName)_TO_$($_)`";"}
                $ZoningTargets | %{$SSHCommand += "zonedelete `"$($AliasName)_TO_$($_)`";"}
                $SSHCommand += "alidelete `'$AliasName`';"
                $SSHCommand += "echo `'y`' | cfgsave ; echo `'y`' | cfgenable cfg"
                if($ScriptOnly){
                        $SSHCommand
                }
                else{
                    if ($PSCmdlet.ShouldProcess($Switch.Name,$SSHCommand)){
                        Invoke-SSHCommand -SSHSession $SshSessions -Command "$SSHCommand"
                    }
                }
            
            Remove-SSHSession -SSHSession $SshSessions
        }
    }
}

function Set-BrocadeZoningAuto {
    [CmdletBinding()]
      param
      (
    [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = "VMZoning")]$FabricDetail,

    [Parameter(Mandatory, ParameterSetName = "PhysicalServerZoning")]$Hostname,          

    [Parameter(Mandatory, ParameterSetName = "PhysicalServerZoning")]$FabricAWWPN,
    [Parameter(Mandatory, ParameterSetName = "PhysicalServerZoning")]$FabricBWWPN,

    [Parameter(Mandatory, ParameterSetName = "PhysicalServerZoning")]
    [Parameter(Mandatory, ParameterSetName = "VMZoning")]
    [ValidateSet('VNX5300','VNX2','CX3-20','MD3860F01','MD3860F02','ALL')]$SANSelection
      )
    $BrocadeSW1Credential = Get-PasswordstatePassword -AsCredential -ID 44
    $BrocadeSW2Credential = Get-PasswordstatePassword -AsCredential -ID 45

    if (-not $FabricDetail){
        $FabricDetail = [PSCustomObject][Ordered] @{
            Hostname = $Hostname
            FabricAWWNSetA = $FabricAWWPN
            FabricBWWNSetA = $FabricBWWPN
        }
    }

    if($FabricDetail.FabricAWWNSetB)
    {
        $InitiatorAWWN = ($FabricDetail.FabricAWWPNSetA + ";" + $FabricDetail.fabricAWWPNSetB)
    }
    Else
    {
        
        $InitiatorAWWN = $FabricAWWPN
    }
    if($FabricDetail.FabricBWWNSetB)
    {
        $InitiatorBWWN = ($FabricDetail.FabricBWWPNSetA + ";" + $FabricDetail.FabricBWWPNSetB)
    }
    Else
    {
        $InitiatorBWWN = $FabricBWWPN
    }

    switch ($SanSelection)
        {
            "VNX5300" {
                $TargetInitiatorA = "VNX1_A2;VNX1_B2"
                $TargetInitiatorB = "VNX1_A3;VNX1_B3"
            }
            "VNX2" {
                $TargetInitiatorA = "VNX2_A2_P0;VNX2_A2_P1;VNX2_B2_P0;VNX2_B2_P1"
                $TargetInitiatorB = "VNX2_A2_P2;VNX2_A2_P3;VNX2_B2_P2;VNX2_B2_P3"
            }
            "CX3-20" {
                $TargetInitiatorA = "Yosemite_SAN_A0;Yosemite_SAN_B1"
                $TargetInitiatorB = "Yosemite_SAN_A1;Yosemite_SAN_B0"
            }
            "ALL" {
                    $TargetInitiatorA = "VNX2_A2_P0;VNX2_A2_P1;VNX2_B2_P0;VNX2_B2_P1;Yosemite_SAN_A0;Yosemite_SAN_B1;VNX1_A2;VNX1_B2;MD3860F_SP0_P0;MD3860F_SP1_P0;MD3860F02_SP0_P0;MD3860F02_SP1_P0"
                    $TargetInitiatorB = "VNX2_A2_P2;VNX2_A2_P3;VNX2_B2_P2;VNX2_B2_P3;Yosemite_SAN_A1;Yosemite_SAN_B0;VNX1_A3;VNX1_B3;MD3860F_SP0_P1;MD3860F_SP1_P1;MD3860F02_SP0_P1;MD3860F02_SP1_P1"
            }
            "MD3860F01" {
                $TargetInitiatorA = "MD3860F_SP0_P0;MD3860F_SP1_P0"
                $TargetInitiatorB = "MD3860F_SP0_P1;MD3860F_SP1_P1"
            }
            "MD3860F02" {
                $TargetInitiatorA = "MD3860F02_SP0_P0;MD3860F02_SP1_P0"
                $TargetInitiatorB = "MD3860F02_SP0_P1;MD3860F02_SP1_P1"
            }

            `
        }

    $FabricDetail.Hostname = $FabricDetail.Hostname -replace "-",""

    $ConfigMemberA = New-Object psobject
    $ConfigMemberA | Add-Member InitiatorAName $FabricDetail.Hostname
    $ConfigMemberA | Add-Member InitiatorAWWN $InitiatorAWWN
    $ConfigMemberA | Add-Member AliasNameA (($FabricDetail.Hostname).ToUpper() + "_FC0")
    $ConfigMemberA | Add-Member ZoneNameA ($FabricDetail.Hostname + "_TO_SANS").ToUpper()
    $ConfigMemberA | Add-Member ZoneTargetsA $TargetInitiatorA
    
    $ConfigMemberB = New-Object psobject
    $ConfigMemberB | Add-Member InitiatorBName $FabricDetail.Hostname
    $ConfigMemberB | Add-Member InitiatorBWWN $InitiatorBWWN
    $ConfigMemberB | Add-Member AliasNameB (($FabricDetail.Hostname).ToUpper() + "_FC1")
    $ConfigMemberB | Add-Member ZoneNameB ($FabricDetail.Hostname + "_TO_SANS").ToUpper()
    $ConfigMemberB | Add-Member ZoneTargetsB $TargetInitiatorB
    $FabricASSHScript += "alicreate `'$($ConfigMemberA.AliasNameA)`', `'$($ConfigMemberA.InitiatorAWWN)`' ;`n"
    $ConfigMemberA.ZoneTargetsA -split ";" | %{$FabricASSHScript += "zonecreate $($ConfigMemberA.AliasNameA)_TO_$($_), `'$($ConfigMemberA.AliasNameA);$($_)`' ;`n"}
    $ConfigMemberA.ZoneTargetsA -split ";" | %{$FabricASSHScript += "cfgadd cfg, $($ConfigMemberA.AliasNameA)_TO_$($_);`n"}
    $FabricASSHScript += "echo `'y`' | cfgsave ; echo `'y`' | cfgenable cfg`n"

    $FabricBSSHScript += "alicreate `'$($ConfigMemberB.AliasNameB)`', `'$($ConfigMemberB.InitiatorBWWN)`' ;`n"
    $ConfigMemberB.ZoneTargetsB -split ";" | %{$FabricBSSHScript += "zonecreate $($ConfigMemberB.AliasNameB)_TO_$($_), `'$($ConfigMemberB.AliasNameB);$($_)`' ;`n"}
    $ConfigMemberB.ZoneTargetsB -split ";" | %{$FabricBSSHScript += "cfgadd cfg, $($ConfigMemberB.AliasNameB)_TO_$($_);`n"}
    $FabricBSSHScript += "echo `'y`' | cfgsave ; echo `'y`' | cfgenable cfg`n"


    New-SSHSession -ComputerName brocadesw1 -Credential $BrocadeSW1Credential -AcceptKey
    Invoke-SSHCommand -SSHSession (Get-SSHSession) -Command $FabricASSHScript
    get-sshsession | Remove-SSHSession
    New-SSHSession -ComputerName brocadesw2 -Credential $BrocadeSW1Credential -AcceptKey
    Invoke-SSHCommand -SSHSession (Get-SSHSession) -Command $FabricBSSHScript
    Get-SSHSession | Remove-SSHSession
}

function Set-VNXLUNSize{
    param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        $LUNID,

        [Parameter(Mandatory)]
        $Capacity,

        [Parameter(Mandatory)]
        [ValidateSet("VNX5200","VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstatePassword -ID $TervisStorageArrayDetails.PasswordstateCredentialID

    $command = "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) lun -expand -l $LUNID -capacity $Capacity"
    Invoke-Expression -Command $Command
}

function Get-TervisVMStorageInCSVsByArray {
    $GlobalVMs = Find-TervisVM -ClusterName hypervcluster5
    $ProductionVMsRaw = $GlobalVMs | where {($_.name -NotMatch "eps-") -and ($_.name -notmatch "dlt-")}
    $NonProductionVMsRaw = $GlobalVMs | where {($_.name -Match "eps-") -or ($_.name -match "dlt-")}

    $ProductionVMs = foreach ($ProdVM in $ProductionVMsRaw){
        $ProdVM | Get-TervisVM
    }

    $NonProductionVMs = foreach ($NonProdVM in $NonProductionVMsRaw){
        $NonProdVM | Get-TervisVM
    }

    $LUNsOn5300 = Get-LUNSFromVNX -TervisStorageArraySelection VNX5300
    $LUNsOn5200 = Get-LUNSFromVNX -TervisStorageArraySelection VNX5200
    $CSVs = Get-ClusterSharedVolume -Cluster hypervcluster5 | select -property @{N='Name';E={$_.Name}},@{N='FriendlyName';E={$_.SharedVolumeInfo.friendlyvolumename}}
    $CSVs5300 = $CSVs | where name -match "5300"
    $CSVs5200 = $CSVs | where name -match "5200"

    $ProductionVHDs = foreach($VM in $ProductionVMs){
        $VHDs = Get-VHD -ComputerName $VM.computername -VMId $VM.vmid    
            $VHDTotalSize = 0
        $VHDDetails = foreach($VHD in $VHDs){
            [PSCustomObject]@{
                Volume = ($VHD.path.split("\"))[2]
                Path = $VHD.Path
                Size = ($VHD.FileSize / 1GB).ToString("0.00")
                Array = (($CSVs | where {(($VHD.path.Split("\"))[0..2] -join "\") -in $_.FriendlyName}).Name).replace(')',"").split(" ") | select -last 1
            }
            $VHDTotalSize += $VHD.FileSize
        }
        [PSCustomObject]@{
            VMName = $VM.Name
            VHDTotalSize = ($VHDTotalSize / 1GB)
            Array = $VHDDetails.Array | Sort-Object -Unique
            VHDDetails = $VHDDetails
        }
    }
    $NonProductionVHDs = foreach($VM in $NonProductionVMs){
        $VHDs = Get-VHD -ComputerName $VM.computername -VMId $VM.vmid    
            $VHDTotalSize = 0
        $VHDDetails = foreach($VHD in $VHDs){
            [PSCustomObject]@{
                Volume = ($VHD.path.split("\"))[2]
                Path = $VHD.Path
                Size = ($VHD.Size / 1GB).ToString("0.00")
                Array = (($CSVs | where {(($VHD.path.Split("\"))[0..2] -join "\") -in $_.FriendlyName}).Name).replace(')',"").split(" ") | select -last 1
            }
            $VHDTotalSize += $VHD.Size
        }
        [PSCustomObject]@{
            VMName = $VM.Name
            VHDTotalSize = ($VHDTotalSize / 1GB)
            Array = $VHDDetails.Array | Sort-Object -Unique
            VHDDetails = $VHDDetails
        }
    }

    $CSVUtilizationByArray = [pscustomobject]@{
        Environment = "Production"
        Array = "VNX5300"
        Size = (($ProductionVHDs | where Array -Contains 5300 | Measure-Object -Property VHDTotalSize -sum).sum).ToString("#")
    },
    [pscustomobject]@{
        Environment = "Production"
        Array = "VNX5200"
        Size = (($ProductionVHDs | where Array -Contains 5200 | Measure-Object -Property VHDTotalSize -sum).sum).ToString("#")
    },
    [pscustomobject]@{
        Environment = "Non-Production"
        Array = "VNX5300"
        Size = (($NonProductionVHDs | where Array -Contains 5300 | Measure-Object -Property VHDTotalSize -sum).sum).ToString("#")
    },
    [pscustomobject]@{
        Environment = "Non-Production"
        Array = "VNX5200"
        Size = (($NonProductionVHDs | where Array -Contains 5200 | Measure-Object -Property VHDTotalSize -sum).sum).ToString("#")
    }
    $ProductionVHDs | Out-GridView
    $NonProductionVHDs | Out-GridView
    $CSVUtilizationByArray | Out-GridView
}

function Get-BrocadeZoningAliasRecord {
    [CmdletBinding()]
      param
      (
    [Parameter(Mandatory, ValueFromPipeline)]$ComputerName
      )
    $BrocadeSW1Credential = Get-PasswordstatePassword -AsCredential -ID 44
    $BrocadeSW2Credential = Get-PasswordstatePassword -AsCredential -ID 45
    $BrocadeSW1SSHSession = New-SSHSession -ComputerName brocadesw1 -Credential $BrocadeSW1Credential -AcceptKey
    $BrocadeSW2SSHSession = New-SSHSession -ComputerName brocadesw2 -Credential $BrocadeSW1Credential -AcceptKey
    $ComputerNameInBrocadeFormat = ($ComputerName -replace "-","").ToUpper()

    $AliasNameA = ($ComputerNameInBrocadeFormat + "_FC0")
    $AliasNameB = ($ComputerNameInBrocadeFormat + "_FC1")

    if(Computername){
        $SSHCommand = "alishow '*$ComputerNameInBrocadeFormat*'"
    }
    elseif(WWPN){
        $SSHCommand = "alishow '$WWPN'"
    }

    $BrocadeAliShowTemplate = @"
 alias: {Alias*:INFHYPERVC5N13_FC0}
                {WWPN:20:00:00:25:b5:1a:00:1b}
 alias: INFHYPERVC5N14_FC0
                20:00:00:25:b5:1a:00:da
 alias: INFHYPERVC5N15_FC0
                20:00:00:25:b5:1a:00:ba
 alias: {Alias*:INFHYPERVC5N16_FC1}
                20:00:00:25:b5:1a:00:bf
 alias: INFHYPERVC6N10_FC0
                21:00:00:1b:32:9d:a0:e1
 alias: INFHYPERVC6N11_FC1
                21:00:00:1b:32:9d:55:dc
"@
    $FabricAOutput = (Invoke-SSHCommand -SSHSession $BrocadeSW1SSHSession -Command $SSHCommand)
    $FabricBOutput = (Invoke-SSHCommand -SSHSession $BrocadeSW2SSHSession -Command $SSHCommand) 



    $FabricAOutput | %{
        $ParsedOutput = $_.output | ConvertFrom-String -TemplateContent $BrocadeAliShowTemplate
        [PSCustomObject]@{
            SwitchName = $_.Host
            AliasName = $ParsedOutput.Alias
            WWPN = $ParsedOutput.WWPN
        }
    }
    $FabricBOutput | %{
        $ParsedOutput = $_.output | ConvertFrom-String -TemplateContent $BrocadeAliShowTemplate
        [PSCustomObject]@{
            SwitchName = $_.Host
            AliasName = $ParsedOutput.Alias
            WWPN = $ParsedOutput.WWPN
        }
    }

    Get-SSHSession | Remove-SSHSession | Out-Null
}

function Get-BrocadeZoningZoneRecord {
    [CmdletBinding()]
      param
      (
    [Parameter(Mandatory, ValueFromPipeline)]$ComputerName
      )
    $BrocadeSW1Credential = Get-PasswordstatePassword -AsCredential -ID 44
    $BrocadeSW2Credential = Get-PasswordstatePassword -AsCredential -ID 45
    $BrocadeSW1SSHSession = New-SSHSession -ComputerName brocadesw1 -Credential $BrocadeSW1Credential -AcceptKey
    $BrocadeSW2SSHSession = New-SSHSession -ComputerName brocadesw2 -Credential $BrocadeSW1Credential -AcceptKey
    $ComputerNameInBrocadeFormat = ($ComputerName -replace "-","").ToUpper()

    $AliasNameA = ($ComputerNameInBrocadeFormat + "_FC0")
    $AliasNameB = ($ComputerNameInBrocadeFormat + "_FC1")

    $SSHCommand = "zoneshow '*$ComputerNameInBrocadeFormat*'"
    $FabricBSSHScript = "zoneshow '*$ComputerNameInBrocadeFormat*'"

    $BrocadeZoneShowTemplate = @"
 zone:  {Zone*:INFHYPERVC5N16_FC0_TO_MD3860F02_SP0_P0}
                {Members:INFHYPERVC5N16_FC0; MD3860F02_SP0_P0}
 zone:  INFHYPERVC5N16_FC0_TO_MD3860F_SP0_P0
                INFHYPERVC5N16_FC0; MD3860F_SP0_P0
 zone:  {Zone*:INFHYPERVC5N16_FC0_TO_VNX1_A2}
                {Members:INFHYPERVC5N16_FC0; VNX1_A2}
 zone:  INFHYPERVC5N16_FC0_TO_VNX2_A2_P0
                INFHYPERVC5N16_FC0; VNX2_A2_P0
 zone:  {Zone*:SQL_FC0_TO_MD3860F_SP0_P0}
                {Members:SQL_FC0; MD3860F_SP0_P0}
 zone:  SQL_FC0_TO_MD3860F_SP1_P0
                SQL_FC0; MD3860F_SP1_P0
 zone:  {Zone*:INFSCDPMSQL01_FC0_TO_MD3860F_SP0_P0}
                {Members:INFSCDPMSQL01_FC0; MD3860F_SP0_P0}
"@
    $FabricAOutput = (Invoke-SSHCommand -SSHSession $BrocadeSW1SSHSession -Command $SSHCommand)
    $FabricBOutput = (Invoke-SSHCommand -SSHSession $BrocadeSW2SSHSession -Command $FabricBSSHScript) 



    $FabricAOutput | %{
        $ParsedOutput = $_.output | ConvertFrom-String -TemplateContent $BrocadeZoneShowTemplate
        [PSCustomObject]@{
            SwitchName = $_.Host
            ZoneName = $ParsedOutput.Zone
            Members = $ParsedOutput.Members
        }
    }
    $FabricBOutput | %{
        $ParsedOutput = $_.output | ConvertFrom-String -TemplateContent $BrocadeZoneShowTemplate
        [PSCustomObject]@{
            SwitchName = $_.Host
            ZoneName = $ParsedOutput.Zone
            Members = $ParsedOutput.Members
        }
    }

    Get-SSHSession | Remove-SSHSession | Out-Null
}

function Get-VSSSnapshots {
    param(
        [parameter(mandatory)]$ComputerName
    )
    
    $ShadowCopies = Get-WmiObject Win32_Shadowcopy -ComputerName $ComputerName
    
    $ShadowCopies | %{
        $_ | Add-Member -MemberType NoteProperty -Name SnapshotTimeStamp -Value ([management.managementDateTimeConverter]::ToDateTime($_.installdate))
    }
    $ShadowCopies
}

function Get-VSSSnapshotScheduledTask {
    param(
    [Parameter(Mandatory)]$ComputerName,
    [Parameter(Mandatory)]$VolumeId,
    $CimSession
    )
    if($CimSession){
        $CimSession = New-CimSession -ComputerName $Computername
    }
    Get-ScheduledTask | where TaskName -like "*ShadowCopyVolume*$($VolumeId)"
    
    if(-not $CimSession){
        Remove-CimSession -CimSession $CimSession
    }

}

function New-VSSSnapshotScheduledTask {
    param(
    [Parameter(ParameterSetName="Computername",Mandatory)]$ComputerName,
    [Parameter(Mandatory)]$VolumeID,
    [Parameter(Mandatory)]$TaskTrigger,
    [Parameter(ParameterSetName="CimSession",Mandatory)]$CimSession
    )
    $TaskName = "ShadowCopyVolume$VolumeId"
    if(-not $CimSession){
        $CimSession = New-CimSession -ComputerName $Computername
    }
    if ($ScheduledTask = Get-ScheduledTask -CimSession $CimSession | where TaskName -eq $TaskName) {
        Unregister-ScheduledTask -CimSession $CimSession -TaskName $ScheduledTask.TaskName
    }
    $TaskAction = New-ScheduledTaskAction -Execute "C:\Windows\system32\vssadmin.exe" -Argument "Create Shadow /AutoRetry=15 /For=\\?\Volume$($VolumeId)\" -WorkingDirectory "%systemroot%\system32"
    $TaskSettings = New-ScheduledTaskSettingsSet
    
    Register-ScheduledTask -CimSession $CimSession -TaskName $TaskName -Settings $TaskSettings -Action $TaskAction -Trigger $TaskTrigger -User "NT Authority\SYSTEM" -RunLevel Highest

    if(-not $CimSession){
        Remove-CimSession -CimSession $CimSession
    }
}

function Set-TervisFileserverVSSSnapshotScheduledTask {
    param(
        [Parameter(Mandatory)]$Computername,
        $VolumeId
    )
    $CimSession = New-CimSession -ComputerName $Computername
    $Trigger = @(
       $(New-ScheduledTaskTrigger -Daily -At 7am),
       $(New-ScheduledTaskTrigger -Daily -At 3am),
       $(New-ScheduledTaskTrigger -Daily -At 11pm)
    )
    if($VolumeId){
        New-VSSSnapshotScheduledTask -CimSession $CimSession -TaskTrigger $Trigger -VolumeID $VolumeId
    }
    else{
        $Volumes = Get-Volume -CimSession $cimsession | where {($_.driveletter -ne "C") -and ($_.DriveLetter)}
        $Volumes | %{
            $VolumeId = $_.Path | Select-String -Pattern '{[-0-9A-F]+?}' -AllMatches | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
            New-VSSSnapshotScheduledTask -CimSession $CimSession -TaskTrigger $Trigger -VolumeID $VolumeId
        }
    }

    Remove-CimSession $CimSession
}

function Get-VSSProvider {
    param(
        [parameter(mandatory)]$ComputerName
    )
    gwmi Win32_ShadowProvider -ComputerName $ComputerName
}

function Get-VSSContext {
    param(
        [parameter(mandatory)]$ComputerName    )
    gwmi Win32_ShadowContext -ComputerName $ComputerName
}

function Get-VolumesWithVSSData {
    param(
        [parameter(ParameterSetName="Computername",mandatory)]$ComputerName,
        [parameter(ParameterSetName="CimSession",mandatory)]$CimSession
    )
    if(-not $CimSession){
        $CimSession = New-CimSession -ComputerName $Computername
    }
    $Volumes = Get-Volume -CimSession $CimSession | where {($_.DriveLetter -ne "C") -and ($_.Driveletter) -and ($_.DriveType -eq "Fixed")}
    $VSSSnapshots = Get-VSSSnapshots -CimSession $CimSession
    $VSSShadowStorageConsumed = Get-WMIObject -ComputerName $CimSession.ComputerName -Class Win32_ShadowStorage | Select-Object @{n=’UsedSpaceGB’;e={[math]::Round([double]$_.UsedSpace/1GB,3)}}, Volume
    
    foreach ($Volume in $Volumes) {
        $VolumeId = $Volume.Path | Select-String -Pattern '{[-0-9A-F]+?}' -AllMatches | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value
        if((-not ($Snapshots = $VSSSnapshots | where VolumeName -eq $Volume.Path)) -or ($VSSSnapshots.Count -le 1)){
            $Volumes = $Volumes | where DriveLetter -ne $Volume.DriveLetter
            Continue
        }
        $VSSConsumed = $VSSShadowStorageConsumed | where {$_.Volume -match $VolumeId}
        $Volume | Add-Member -Name Snapshots -MemberType NoteProperty -Value $Snapshots -Force
        $Volume | Add-Member -Name VSSConsumed -MemberType NoteProperty -Value $VSSConsumed.UsedSpaceGB -Force
    }
    $Volumes
    if(-not $CimSession){
        Remove-CimSession -CimSession $CimSession
    }
}

function Invoke-CheckFileServerVSSHealth {
    param(
        $ComputerName
    )
    $VolumesWithVSSData = Get-VolumesWithVSSData -ComputerName $ComputerName
    foreach($Volume in $volumesWithVssData){
        $OldestSnapshotDate = $Volume.Snapshots.snapshottimestamp | Sort-Object | select -First 1
        $NewestSnapshotDate = $Volume.Snapshots.snapshottimestamp | Sort-Object | select -Last 1
        $DaysRetained = (New-TimeSpan -Start $OldestSnapshotDate -End (get-date -hour 23 -Minute 59)).Days
        $SnapshotRangeToCalculate = $Volume.Snapshots | where snapshottimestamp -lt (get-date -Hour 00 -Minute 00)
        $RPOSuccessRate = (($SnapshotRangeToCalculate.count) / ($DaysRetained * 3)) * 100
        [PSCustomObject]@{
            VolumeLable = $Volume.FileSystemLabel
            DriveLetter = $Volume.DriveLetter
            CapacityGB = "{0:n2}" -f ($Volume.Size / 1GB)
            AvailableGB = "{0:n2}" -f ($Volume.SizeRemaining / 1GB)
            OldestSnapshotDate = $OldestSnapshotDate
            NewestSnapshotDate = $NewestSnapshotDate
            SnapshotCount = $Volume.Snapshots.Count
            DaysRetained = $DaysRetained
            VSSUsedStorageGB = "{0:n2}" -f ($Volume.VSSConsumed)
            RPSuccessRatio = $RPOSuccessRate.ToString("#.#")
        }
    }
}

function Invoke-PruneVSSSnapshots{
    param(
        [parameter(ParameterSetName="Computername",mandatory)]$ComputerName,
        [parameter(ParameterSetName="CimSession",mandatory)]$CimSession
    )
    if(-not $CimSession){
        $CimSession = New-CimSession -ComputerName $Computername
    }
    $VSSSnapshots = Get-VSSSnapshots -CimSession $CimSession
    $SnapshotsToPrune = $VSSSnapshots | where snapshottimestamp -lt (get-date -Hour 00 -Minute 00).AddDays(-16) | select -first 1

    Invoke-Command -ComputerName $CimSession.ComputerName -ScriptBlock {
        param(
            $SnapshotsToPrune
        )
        $SnapshotsToPrune | %{& vssadmin /Delete Shadows /Shadow=$($_.ID) /Quiet}
    } -ArgumentList $SnapshotsToPrune

    if(-not $CimSession){
        Remove-CimSession $CimSession
    }
}