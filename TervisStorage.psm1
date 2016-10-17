﻿$TervisStorageArrays = [pscustomobject][ordered]@{
    Name="VNX5200"
    PasswordstateCredentialID = "2574"
    IPAddress = "10.172.248.160"
},
[pscustomobject][ordered]@{
    Name="VNX5300"
    PasswordstateCredentialID = "3982"
    IPAddress = "10.172.248.153"
}

function Get-TervisStorageArrayDetails{
    param(
        [Parameter(Mandatory)][ValidateSet(“VNX5200”,”VNX5300”)][String]$StorageArrayName
    )
    $TervisStorageArrays | Where name -EQ $StorageArrayName
}

function Get-LUNSFromVNX {
    param(
        [Parameter(Mandatory)]
        [ValidateSet(“VNX5200”,”VNX5300")]
        $TervisStorageArraySelection
    )
    $TervisStorageArrayDetails = Get-TervisStorageArrayDetails -StorageArrayName $TervisStorageArraySelection
    $TervisStorageArrayPasswordDetails = Get-PasswordstateEntryDetails -PasswordID $TervisStorageArrayDetails.PasswordstateCredentialID



    $GetLUNOutput = Invoke-Command -ScriptBlock {& 'c:\program files\emc\naviseccli.exe' -scope 0 -h $TervisStorageArrayDetails.IPAddress -user $TervisStorageArrayPasswordDetails.Username -password $TervisStorageArrayPasswordDetails.Password getlun}
    $GetLUNOutput | ConvertFrom-String -templatecontent $EMCLUNList
}   

$EMCLUNList = @"
LOGICAL UNIT NUMBER {LUNID*:45}
Prefetch size (blocks) =         N/A
Prefetch multiplier =            N/A
Segment size (blocks) =          N/A
Segment multiplier =             N/A
Maximum prefetch (blocks) =      N/A
Prefetch Disable Size (blocks) = N/A
Prefetch idle count =            N/A

Prefetching:                N/A
Prefetched data retained:   N/A

Read cache configured according to
 specified parameters.

Name                        {LUNNAME:DFS_Creative_Web}
Minimum latency reads N/A

RAID Type:                  N/A
RAIDGroup ID:               N/A
State:                      Bound
Stripe Crossing:            0
Element Size:               0
Current owner:              {CurrentOwner:SP A}
Offset:                     N/A
Auto-trespass:              DISABLED
Auto-assign:                DISABLED
Write cache:                ENABLED
Read cache:                 ENABLED
Idle Threshold:             N/A
Idle Delay Time:            N/A
Write Aside Size:           0
Default Owner:              {DefaultOwner:SP A}
Rebuild Priority:           N/A
Verify Priority:            N/A
Prct Reads Forced Flushed:  N/A
Prct Writes Forced Flushed: N/A
Prct Rebuilt:               100
Prct Bound:                 N/A
LUN Capacity(Megabytes):    {LUNCapacity:716800}
LUN Capacity(Blocks):       1468006400
UID:                        {LUNUID:60:06:01:60:20:B0:38:00:1D:84:4C:CD:B2:87:E4:11}
Is Private:                 NO
Snapshots List:             Not Available
MirrorView Name if any:     Not Available

LOGICAL UNIT NUMBER {LUNID*:1760}
Prefetch size (blocks) =         N/A
Prefetch multiplier =            N/A
Segment size (blocks) =          N/A
Segment multiplier =             N/A
Maximum prefetch (blocks) =      N/A
Prefetch Disable Size (blocks) = N/A
Prefetch idle count =            N/A

Prefetching:                N/A
Prefetched data retained:   N/A

Read cache configured according to
 specified parameters.

Name                        {LUNName:Hyper V Cluster 5 Cluster Shared Volume 16}
Minimum latency reads N/A

RAID Type:                  N/A
RAIDGroup ID:               N/A
State:                      Bound
Stripe Crossing:            0
Element Size:               0
Current owner:              {CurrentOwner:SP B}
Offset:                     N/A
Auto-trespass:              DISABLED
Auto-assign:                DISABLED
Write cache:                ENABLED
Read cache:                 ENABLED
Idle Threshold:             N/A
Idle Delay Time:            N/A
Write Aside Size:           0
Default Owner:              {DefaultOwner:SP B}
Rebuild Priority:           N/A
Verify Priority:            N/A
Prct Reads Forced Flushed:  N/A
Prct Writes Forced Flushed: N/A
Prct Rebuilt:               100
Prct Bound:                 N/A
LUN Capacity(Megabytes):    {LUNCapacity:1048576}
LUN Capacity(Blocks):       2147483648
UID:                        {LUNUID:60:06:01:60:20:B0:38:00:B9:8A:2C:2B:D0:11:E4:11}
Is Private:                 NO
Snapshots List:             Not Available
MirrorView Name if any:     Not Available

LOGICAL UNIT NUMBER {LUNID*:63840}
Prefetch size (blocks) =         N/A
Prefetch multiplier =            N/A
Segment size (blocks) =          N/A
Segment multiplier =             N/A
Maximum prefetch (blocks) =      N/A
Prefetch Disable Size (blocks) = N/A
Prefetch idle count =            N/A

Prefetching:                N/A
Prefetched data retained:   N/A

Read cache configured according to
 specified parameters.

Name                        {LUNName:EBSDB-PRD_ARCHIVELOGS_VNX2_EPS-ODBEE01_SMP}
Minimum latency reads N/A

RAID Type:                  N/A
RAIDGroup ID:               N/A
State:                      Bound
Stripe Crossing:            0
Element Size:               0
Current owner:              {CurrentOwner:SP A}
Offset:                     N/A
Auto-trespass:              DISABLED
Auto-assign:                DISABLED
Write cache:                ENABLED
Read cache:                 ENABLED
Idle Threshold:             N/A
Idle Delay Time:            N/A
Write Aside Size:           0
Default Owner:              {DefaultOwner:SP A}
Rebuild Priority:           N/A
Verify Priority:            N/A
Prct Reads Forced Flushed:  N/A
Prct Writes Forced Flushed: N/A
Prct Rebuilt:               100
Prct Bound:                 N/A
LUN Capacity(Megabytes):    {LUNCapacity:512000}
LUN Capacity(Blocks):       1048576000
UID:                        {LUNUID:60:06:01:60:20:B0:38:00:F5:82:CE:13:F1:F8:E5:11}
Is Private:                 NO
Snapshots List:             Not Available
MirrorView Name if any:     Not Available

LOGICAL UNIT NUMBER {LUNID*:20}
Prefetch size (blocks) =         N/A
Prefetch multiplier =            N/A
Segment size (blocks) =          N/A
Segment multiplier =             N/A
Maximum prefetch (blocks) =      N/A
Prefetch Disable Size (blocks) = N/A
Prefetch idle count =            N/A

Prefetching:                N/A
Prefetched data retained:   N/A

Read cache configured according to
 specified parameters.

Name                        {LUNName:ESXi4 Datastore}
Minimum latency reads N/A

RAID Type:                  N/A
RAIDGroup ID:               N/A
State:                      Bound
Stripe Crossing:            0
Element Size:               0
Current owner:              {CurrentOwner:SP B}
Offset:                     N/A
Auto-trespass:              DISABLED
Auto-assign:                DISABLED
Write cache:                ENABLED
Read cache:                 ENABLED
Idle Threshold:             N/A
Idle Delay Time:            N/A
Write Aside Size:           0
Default Owner:              {DefaultOwner:SP B}
Rebuild Priority:           N/A
Verify Priority:            N/A
Prct Reads Forced Flushed:  N/A
Prct Writes Forced Flushed: N/A
Prct Rebuilt:               100
Prct Bound:                 N/A
LUN Capacity(Megabytes):    {LUNCapacity:1536000}
LUN Capacity(Blocks):       3145728000
UID:                        {LUNUID:60:06:01:60:20:B0:38:00:B4:F1:23:6C:60:4A:E4:11}
Is Private:                 NO
Snapshots List:             Not Available
MirrorView Name if any:     Not Available

LOGICAL UNIT NUMBER {LUNID*:1567}
Prefetch size (blocks) =         0
Prefetch multiplier =            0
Segment size (blocks) =          0
Segment multiplier =             0
Maximum prefetch (blocks) =      0
Prefetch Disable Size (blocks) = 0
Prefetch idle count =            0

Prefetching: NO
Prefetched data retained    NO

Read cache configured according to
 specified parameters.

Name                        {LUNName:OracleBIEBS-DB_ArchiveLogs}
Minimum latency reads N/A

RAID Type:                  N/A
RAIDGroup ID:               N/A
State:                      Bound
Stripe Crossing:            0
Element Size:               0
Current owner:              {CurrentOwner:SP B}
Offset:                     N/A
Auto-trespass:              DISABLED
Auto-assign:                DISABLED
Write cache:                ENABLED
Read cache:                 ENABLED
Idle Threshold:             0
Idle Delay Time:            0
Write Aside Size:           0
Default Owner:              {DefaultOwner:SP B}
Rebuild Priority:           N/A
Verify Priority:            N/A
Prct Reads Forced Flushed:  0
Prct Writes Forced Flushed: 0
Prct Rebuilt:               100
Prct Bound:                 100
LUN Capacity(Megabytes):    {LUNCapacity:102400}
LUN Capacity(Blocks):       209715200
UID:                        {LUNUID:60:06:01:60:3D:C1:2E:00:56:D7:C8:EA:89:69:E3:11}
Is Private:                 NO
Snapshots List:             Not Available
MirrorView Name if any:     Not Available

LOGICAL UNIT NUMBER {LUNID*:1075}
Prefetch size (blocks) =         0
Prefetch multiplier =            0
Segment size (blocks) =          0
Segment multiplier =             0
Maximum prefetch (blocks) =      0
Prefetch Disable Size (blocks) = 0
Prefetch idle count =            0

Prefetching: NO
Prefetched data retained    NO

Read cache configured according to
 specified parameters.

Name                        {LUNName:p-ias02_dmz-dmzbin}
Minimum latency reads N/A

RAID Type:                  N/A
RAIDGroup ID:               N/A
State:                      Bound
Stripe Crossing:            0
Element Size:               0
Current owner:              {CurrentOwner:SP B}
Offset:                     N/A
Auto-trespass:              DISABLED
Auto-assign:                DISABLED
Write cache:                ENABLED
Read cache:                 ENABLED
Idle Threshold:             0
Idle Delay Time:            0
Write Aside Size:           0
Default Owner:              {DefaultOwner:SP B}
Rebuild Priority:           N/A
Verify Priority:            N/A
Prct Reads Forced Flushed:  0
Prct Writes Forced Flushed: 0
Prct Rebuilt:               100
Prct Bound:                 100
LUN Capacity(Megabytes):    {LUNCapacity:102400}
LUN Capacity(Blocks):       209715200
UID:                        {LUNUID:60:06:01:60:3D:C1:2E:00:48:24:06:90:ED:D9:E3:11}
Is Private:                 NO
Snapshots List:             Not Available
MirrorView Name if any:     Not Available

LOGICAL UNIT NUMBER {LUNId*:1084}
Prefetch size (blocks) =         0
Prefetch multiplier =            0
Segment size (blocks) =          0
Segment multiplier =             0
Maximum prefetch (blocks) =      0
Prefetch Disable Size (blocks) = 0
Prefetch idle count =            0

Prefetching: NO
Prefetched data retained    NO

Read cache configured according to
 specified parameters.

Name                        {LUNName:P-IAS03_EBSBIN}
Minimum latency reads N/A

RAID Type:                  N/A
RAIDGroup ID:               N/A
State:                      Bound
Stripe Crossing:            0
Element Size:               0
Current owner:              {CurrentOwner:SP A}
Offset:                     N/A
Auto-trespass:              DISABLED
Auto-assign:                DISABLED
Write cache:                ENABLED
Read cache:                 ENABLED
Idle Threshold:             0
Idle Delay Time:            0
Write Aside Size:           0
Default Owner:              {DefaultOwner:SP A}
Rebuild Priority:           N/A
Verify Priority:            N/A
Prct Reads Forced Flushed:  0
Prct Writes Forced Flushed: 0
Prct Rebuilt:               100
Prct Bound:                 100
LUN Capacity(Megabytes):    {LUNCapacity:204800}
LUN Capacity(Blocks):       419430400
UID:                        {LUNUID:60:06:01:60:3D:C1:2E:00:56:31:33:96:7F:DB:E3:11}
Is Private:                 NO
Snapshots List:             Not Available
MirrorView Name if any:     Not Available

LOGICAL UNIT NUMBER {LUNID*:4065}
Prefetch size (blocks) =         0
Prefetch multiplier =            4
Segment size (blocks) =          0
Segment multiplier =             4
Maximum prefetch (blocks) =      4096
Prefetch Disable Size (blocks) = 4097
Prefetch idle count =            40

Variable length prefetching YES
Prefetched data retained    YES

Read cache configured according to
 specified parameters.

Total Hard Errors:          0
Total Soft Errors:          0
Total Queue Length:         0
Name                        {LUNName:Hot Spare LUN 4065}
Minimum latency reads N/A

Read Histogram[0] 0
Read Histogram[1] 0
Read Histogram[2] 0
Read Histogram[3] 0
Read Histogram[4] 0
Read Histogram[5] 0
Read Histogram[6] 0
Read Histogram[7] 0
Read Histogram[8] 0
Read Histogram[9] 0
Read Histogram overflows 0

Write Histogram[0] 0
Write Histogram[1] 0
Write Histogram[2] 0
Write Histogram[3] 0
Write Histogram[4] 0
Write Histogram[5] 0
Write Histogram[6] 0
Write Histogram[7] 0
Write Histogram[8] 0
Write Histogram[9] 0
Write Histogram overflows 0

Read Requests:              0
Write Requests:             0
Blocks read:                0
Blocks written:             0
Read cache hits:            0
Read cache misses:          N/A
Prefetched blocks:          0
Unused prefetched blocks:   0
Write cache hits:           0
Forced flushes:             0
Read Hit Ratio:             N/A
Write Hit Ratio:            N/A
RAID Type:                  Hot Spare
RAIDGroup ID:               115
State:                      Bound
Stripe Crossing:            0
Element Size:               N/A
Current owner:              {CurrentOwner:N/A}
Offset:                     0
Auto-trespass:              ENABLED
Auto-assign:                N/A
Write cache:                DISABLED
Read cache:                 DISABLED
Idle Threshold:             0
Idle Delay Time:            20
Write Aside Size:           2048
Default Owner:              {DefaultOwner:SP A}
Rebuild Priority:           N/A
Verify Priority:            N/A
Prct Reads Forced Flushed:  0
Prct Writes Forced Flushed: 0
Prct Rebuilt:               N/A
Prct Bound:                 100
LUN Capacity(Megabytes):    {LUNCapacity:93815}
LUN Capacity(Blocks):       192133120
UID:                        {LUNUID:60:06:01:60:21:D1:2E:00:52:67:BB:83:20:A4:E1:11}
Bus 0 Enclosure 0  Disk 14  Queue Length:               267199
Bus 0 Enclosure 0  Disk 14  Hard Read Errors:           0
Bus 0 Enclosure 0  Disk 14  Hard Write Errors:          0
Bus 0 Enclosure 0  Disk 14  Soft Read Errors:           0
Bus 0 Enclosure 0  Disk 14  Soft Write Errors:          0

Bus 0 Enclosure 0  Disk 14   Hot Spare Ready
Reads:            267181
Writes:           0
Blocks Read:      1724022784
Blocks Written:   0
Queue Max:        N/A
Queue Avg:        N/A
Avg Service Time: N/A
Prct Idle:        99.88
Prct Busy:        0.11
Remapped Sectors: N/A
Read Retries:     N/A
Write Retries:    N/A
Is Private:                 YES
Snapshots List:             Not Available
MirrorView Name if any:     Not Available

LOGICAL UNIT NUMBER {LUNID*:4063}
Prefetch size (blocks) =         0
Prefetch multiplier =            4
Segment size (blocks) =          0
Segment multiplier =             4
Maximum prefetch (blocks) =      4096
Prefetch Disable Size (blocks) = 4097
Prefetch idle count =            40

Variable length prefetching YES
Prefetched data retained    YES

Read cache configured according to
 specified parameters.

Total Hard Errors:          0
Total Soft Errors:          0
Total Queue Length:         0
Name                        {LUNName:Hot Spare LUN 4063}
Minimum latency reads N/A

Read Histogram[0] 0
Read Histogram[1] 0
Read Histogram[2] 0
Read Histogram[3] 0
Read Histogram[4] 0
Read Histogram[5] 0
Read Histogram[6] 0
Read Histogram[7] 0
Read Histogram[8] 0
Read Histogram[9] 0
Read Histogram overflows 0

Write Histogram[0] 0
Write Histogram[1] 0
Write Histogram[2] 0
Write Histogram[3] 0
Write Histogram[4] 0
Write Histogram[5] 0
Write Histogram[6] 0
Write Histogram[7] 0
Write Histogram[8] 0
Write Histogram[9] 0
Write Histogram overflows 0

Read Requests:              0
Write Requests:             0
Blocks read:                0
Blocks written:             0
Read cache hits:            0
Read cache misses:          N/A
Prefetched blocks:          0
Unused prefetched blocks:   0
Write cache hits:           0
Forced flushes:             0
Read Hit Ratio:             N/A
Write Hit Ratio:            N/A
RAID Type:                  Hot Spare
RAIDGroup ID:               117
State:                      Bound
Stripe Crossing:            0
Element Size:               N/A
Current owner:              {CurrentOwner:N/A}
Offset:                     0
Auto-trespass:              ENABLED
Auto-assign:                N/A
Write cache:                DISABLED
Read cache:                 DISABLED
Idle Threshold:             0
Idle Delay Time:            20
Write Aside Size:           2048
Default Owner:              {DefaultOwner:SP A}
Rebuild Priority:           N/A
Verify Priority:            N/A
Prct Reads Forced Flushed:  0
Prct Writes Forced Flushed: 0
Prct Rebuilt:               N/A
Prct Bound:                 100
LUN Capacity(Megabytes):    {LUNCapacity:1877603}
LUN Capacity(Blocks):       3845330944
UID:                        {LUNUID:60:06:01:60:21:D1:2E:00:CC:C8:83:BC:20:A4:E1:11}
Bus 1 Enclosure 0  Disk 14  Queue Length:               267209
Bus 1 Enclosure 0  Disk 14  Hard Read Errors:           0
Bus 1 Enclosure 0  Disk 14  Hard Write Errors:          0
Bus 1 Enclosure 0  Disk 14  Soft Read Errors:           0
Bus 1 Enclosure 0  Disk 14  Soft Write Errors:          0

Bus 1 Enclosure 0  Disk 14   Hot Spare Ready
Reads:            267209
Writes:           0
Blocks Read:      1724692480
Blocks Written:   0
Queue Max:        N/A
Queue Avg:        N/A
Avg Service Time: N/A
Prct Idle:        99.80
Prct Busy:        0.19
Remapped Sectors: N/A
Read Retries:     N/A
Write Retries:    N/A
Is Private:                 YES
Snapshots List:             Not Available
MirrorView Name if any:     Not Available
"@