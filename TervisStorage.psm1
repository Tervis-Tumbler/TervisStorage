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
        Targets = "MD3860F_P10_SP0_P0;MD3860F_P10_SP1_P0"
    },
    [psobject][ordered]@{
        Name = "FabricB"
        Targets = "MD3860F_P10_SP0_P1;MD3860F_P10_SP1_P1"
    }
}

function Get-TervisStorageZoningTargets{
    param(
        #[Parameter()][ValidateSet(“BrocadeSW1”,”BrocadeSW2”)][String]$BrocadeSwitch
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
        [Parameter(Mandatory)][ValidateSet(“VNX5200”,”VNX5300”)][String]$StorageArrayName,
        [Parameter()][ValidateSet(“SPA”,”SPB”)][string]$StorageProcessor = "SPA"
#        $StorageProcessor = "SPA"
    )
    $StorageArrayInfo = $TervisStorageArrayInfo | Where name -EQ $StorageArrayName
    $TervisStorageArrayPasswordDetails = Get-PasswordstateEntryDetails -PasswordID $StorageArrayInfo.PasswordstateCredentialID
    if ($StorageProcessor -eq "SPA") {$SPIPAddress = $TervisStorageArrayPasswordDetails.GenericField1}
    if ($StorageProcessor -eq "SPB") {$SPIPAddress = $TervisStorageArrayPasswordDetails.GenericField2}

    $StorageArrayInfo | Add-Member -MemberType ScriptProperty -Name IPAddress -Value {(Resolve-DnsName -Name $this.Hostname).IPAddress} -Force
    $StorageArrayInfo | Add-Member -MemberType NoteProperty -Name SPIPAddress -Value $SPIPAddress -Force
    $StorageArrayInfo

}

function Get-TervisBrocadeDetails{
    param(
        [Parameter()][ValidateSet(“BrocadeSW1”,”BrocadeSW2”)][String]$BrocadeSwitch
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
        [Parameter(Mandatory)][ValidateSet(“VNX5200”,”VNX5300”)][String]$StorageArrayName,
        [Parameter(Mandatory)][ValidateSet(“SPA”,”SPB”)]$StorageProcessor,
        [Switch]$Today
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $StorageArrayName -StorageProcessor $StorageProcessor
    $TervisStorageArrayPasswordDetails = Get-PasswordstateEntryDetails -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID
    $RawGetFileListOutput = & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $($TervisStorageArrayDetails.SPIPAddress) -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) managefiles -list
    $SPFileList = $RawGetFileListOutput | ConvertFrom-String -TemplateFile $PSScriptRoot\VNX_GetFileList_Template
    if ($Today) {
        $SPFileList | Where-Object Timestamp -ge (get-date).AddDays(-1) | Sort-Object -Property timestamp -Descending
    }
    else { $SPFileList | Sort-Object -Property timestamp -Descending }
}

function invoke-GenerateVNXSPCollect {
    param (
        [Parameter(Mandatory)][ValidateSet(“VNX5200”,”VNX5300”)][String]$StorageArrayName,
        [Parameter(Mandatory)][ValidateSet(“SPA”,”SPB”)]$StorageProcessor
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $StorageArrayName -StorageProcessor $StorageProcessor
    $TervisStorageArrayPasswordDetails = Get-PasswordstateEntryDetails -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID

    Invoke-Command -ScriptBlock {& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $($TervisStorageArrayDetails.SPIPAddress) -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) spcollect}
#    & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayPasswordDetails.GenericField2 -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password naviseccli spcollect
}

function Get-VNXArrayFaults {
    param (
        [Parameter(Mandatory)][ValidateSet(“VNX5200”,”VNX5300”)][String]$StorageArrayName,
        [Parameter(Mandatory)][ValidateSet(“SPA”,”SPB”)]$StorageProcessor
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $StorageArrayName    
    $TervisStorageArrayPasswordDetails = Get-PasswordstateEntryDetails -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID

    Invoke-Command -ScriptBlock {& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $($TervisStorageArrayDetails.SPIPAddress) -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -faults -list}
#    & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayPasswordDetails.GenericField2 -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password spcollect
}

function Get-SPLogFilesFromVNX{
    param (
        [Parameter(Mandatory)][ValidateSet(“VNX5200”,”VNX5300”,"All")][String]$StorageArrayName,
        [Parameter(Mandatory)][ValidateSet(“SPA”,”SPB”)]$StorageProcessor,
        [Parameter(Mandatory)]$FileName,
        [Parameter(Mandatory)]$DestinationPath
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $StorageArrayName -StorageProcessor $StorageProcessor
    $TervisStorageArrayPasswordDetails = Get-PasswordstateEntryDetails -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID

    Invoke-Command -ScriptBlock {& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $($TervisStorageArrayDetails.SPIPAddress) -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) managefiles -retrieve -path $DestinationPath -file $FileName -o}
#    & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayPasswordDetails.GenericField2 -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password spcollect
}

function Get-LUNSFromVNX {
    param(
        [Parameter(Mandatory)]
        [ValidateSet(“VNX5200”,”VNX5300","All")]
        $TervisStorageArraySelection
    )

    if($TervisStorageArraySelection -eq "ALL"){
        $SanSelectionList = "vnx5200","vnx5300"
    }
    else{$SanSelectionList = $TervisStorageArraySelection}
    foreach ($Array in $SanSelectionList){
        $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $Array
        $TervisStorageArrayPasswordDetails = Get-PasswordstateEntryDetails -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID
        $RawGetLUNOutput = Invoke-Command -ScriptBlock {& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayDetails.IPAddress -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password getlun}
        $LUNOutput = $RawGetLUNOutput | ConvertFrom-String -TemplateFile $PSScriptRoot\VNX_getlun_Template
        $LUNOutput | Add-Member -MemberType NoteProperty -name "Array" -PassThru -Value $Array
    }
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
        $RawSnapshotOutput = & 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -scope 0 -h $TervisStorageArrayDetails.IPAddress -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password snap -list
        $SnapshotOutput = $RawSnapshotOutput | ConvertFrom-String -TemplateFile $PSScriptRoot\VNX_Snapshotlist_Template
        $SnapshotOutput | Add-Member -MemberType NoteProperty -name "Array" -PassThru -Value $Array

    }
}

function Get-StorageGroupsFromVNX{
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
        [ValidateSet(“VNX5200”,”VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstateCredential -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID -AsPlainText

    $command = "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) snap -create -res $($LUNID) -name '$SnapshotName'"
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
        [ValidateSet(“VNX5200”,”VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstateCredential -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID -AsPlainText

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

function Register-UnisphereHost {
      <#
      .SYNOPSIS
       Uses object from pipe to register Initiators, and create host and storage group in unisphere for selected SAN.
    
      .DESCRIPTION
      Recieves object via pipe from get-vmwwn command. This object will be used to register Unisphere host, initiators, and storage group for specified SAN.
      
      .EXAMPLE
      PS> get-vmwwn testvm | Register-UnisphereHost -SANSelection VNX2 -IPAddress 10.1.1.1
      
      .PARAMETER FabricDetail 
      Object output from Get-VMWWN command. This supplies hostname and initiators.
    
      .PARAMETER SANSelection
      Specify which SAN to configure - VNC5300, VNX5200, or ALL
      
      .PARAMETER IPAddress
      Specify IP Address of the host being configured. This is the VM or physical machine being added to the SAN.
      #>
    
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

    $VNX5300Detail = New-Object psobject
    $VNX5300Detail | Add-Member PortListA @( ("a","0"),("b","0"))
    $VNX5300Detail | Add-Member PortListB @( ("a","1"),("b","1"))
    $VNX5300Detail | Add-Member SPIP "10.172.248.153"
    
    $VNX2Detail = New-Object psobject
    $VNX2Detail | Add-Member PortListA @( ("a","0"),("a","1"),("b","0"),("b","1") )
    $VNX2Detail | Add-Member PortListB @( ("a","2"),("a","3"),("b","2"),("b","3") )
    $VNX2Detail | Add-Member SPIP "10.172.248.160"

    if($SANSelection -eq "ALL"){
        $SanSelectionList = "vnx5200","vnx5300"
    }
    else{$SanSelectionList = $TervisStorageArraySelection}
    
    foreach ($Array in $SanSelectionList){
        
        if($FabricDetail.FabricAWWNSetB)
            {
                $WWNListA = ($FabricDetail.FabricAWWNSetA,$FabricDetail.FabricAWWNSetB)
            }
        Else
            {
                $WWNListA = $FabricDetail.FabricAWWPNSetA
            }
        if($FabricDetail.FabricBWWNSetB)
            {
                $WWNListB = ($FabricDetail.FabricBWWNSetA,$FabricDetail.FabricBWWNSetB)
            }
        Else
            {
                $WWNListB = $FabricDetail.FabricBWWPNSetA
            }
    }
    

    $Command = ""
    foreach ($Array in $SanSelectionList){
        $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $Array
        $TervisStorageArrayPasswordDetails = Get-PasswordstateEntryDetails -PasswordID $($TervisStorageArrayDetails.PasswordstateCredentialID)
        write-host "`nCreating Storage Groups`n"
        $command += "& 'C:\Program Files (x86)\EMC\Navisphere CLI\NaviSECCli.exe' -user $($TervisStorageArrayPasswordDetails.Username) -password $($TervisStorageArrayPasswordDetails.Password) -scope 0 -h $($TervisStorageArrayDetails.IPAddress) storagegroup -create -gname $($FabricDetail.Hostname) ; `n"
    
        Foreach ($WWN in $WWNListA)
            {
            Foreach($Port in $SAN.PortListA)
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
            Foreach($Port in $SAN.PortListB)
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
        $Command
    }/
    else{
        Invoke-Expression -Command $Command
    }
}

function Set-BrocadeZoning {
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
    $BrocadeSW1Credential = Get-PasswordstateCredential -PasswordID 44
    $BrocadeSW2Credential = Get-PasswordstateCredential -PasswordID 45

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
                    $TargetInitiatorA = "VNX2_A2_P0;VNX2_A2_P1;VNX2_B2_P0;VNX2_B2_P1;Yosemite_SAN_A0;Yosemite_SAN_B1;VNX1_A2;VNX1_B2"
                    $TargetInitiatorB = "VNX2_A2_P2;VNX2_A2_P3;VNX2_B2_P2;VNX2_B2_P3;Yosemite_SAN_A1;Yosemite_SAN_B0;VNX1_A3;VNX1_B3"
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
        [Parameter(Mandatory)]$Hostname,          
        
        [Parameter(Mandatory)]
        [ValidateSet('VNX5300','VNX2','CX3-20','MD3860F-HQ','MD3860F-P10','ALL')]$SANSelection
    )
    begin {
    $TervisBrocadeDetails = Get-TervisBrocadeDetails
    $Hostname = $Hostname -replace "-",""
    }
    Process {
        foreach ($Switch in $TervisBrocadeDetails){
            $TervisBrocadePasswordstateCredential = Get-PasswordstateCredential -PasswordID $Switch.PasswordstateCredentialID
            New-SSHSession -ComputerName $Switch.IPAddress -Credential $TervisBrocadePasswordstateCredential
            foreach ($Array in $SANSelection){
                
                $ZoningTargetList = Get-TervisStorageZoningTargets -Array $Array -Fabric $Switch.Fabric
                $AliasName = ("$($Hostname.ToUpper())_$($Switch.InitiatorSuffix)")
                $ZoningTargets = $ZoningTargetList.targets -split ";"
                $SSHCommand = ""
                $ZoningTargets | %{$SSHCommand += "cfgremove `"cfg`", `"$($AliasName)_TO_$($_)`";"}
                $ZoningTargets | %{$SSHCommand += "zonedelete `"$($AliasName)_TO_$($_)`";"}
                $SSHCommand += "alidelete `'$AliasName`';"
                $SSHCommand += "echo `'y`' | cfgsave ; echo `'y`' | cfgenable cfg"
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
    $BrocadeSW1Credential = Get-PasswordstateCredential -PasswordID 44
    $BrocadeSW2Credential = Get-PasswordstateCredential -PasswordID 45

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
                $TargetInitiatorA = "VNX2_A2_P0;VNX2_A2_P1;VNX2_B2_P0;VNX2_B2_P1;Yosemite_SAN_A0;Yosemite_SAN_B1;VNX1_A2;VNX1_B2"
                $TargetInitiatorB = "VNX2_A2_P2;VNX2_A2_P3;VNX2_B2_P2;VNX2_B2_P3;Yosemite_SAN_A1;Yosemite_SAN_B0;VNX1_A3;VNX1_B3"
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
