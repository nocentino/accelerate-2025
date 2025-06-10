##############################################################################################################################
# Protection Group Database Refresh
#
# Scenario: 
#    This script will refresh a database on the target server from a source database on a different server.  This script
#    utilizes a FlashArray Protection Group, to snapshot and clone two volumes simultaneously.  
#
# Prerequisities:
#    1. Two SQL Server instances with a single database, whose data file(s) are contained within 1 volume and log file(s)
#       are contained within a 2nd volume.  
#    2. A Protection Group defined with the two volumes (data and log) as members
# 
# Usage Notes:
#    This simple example assumes there is only one database residing on two different volumes (data & log).  If multiple 
#    databases are present, additional code must be added to offline/online all databases present on the affected volumes 
#    in the Protection Group.  Also note that the Protection Group use may include other volumes without negative impact.  
#    Any extraneous volumes will simply not be utilized during the cloning step.  
# 
# Disclaimer:
#    This example script is provided AS-IS and meant to be a building block to be adapted to fit an individual 
#    organization's infrastructure.
##############################################################################################################################


# Import powershell modules
Import-Module SqlServer
Import-Module PureStoragePowerShellSDK2


# Declare variables
$ArrayName                = 'sn1-x90r2-f06-33.puretec.purestorage.com'                                     # Name of FlashArray
$TargetSQLServer          = 'aen-sql-25-b'                                     # Name of target SQL Server
$ProtectionGroupName      = 'aen-sql-25-a-pg'                                  # Protection Group name in the FlashArray
$TargetDiskSerialNumber1  = '6000c29e73f02b12e4f076c41a268853'                 # Target Disk Serial Number - ex: Data volume
$TargetDiskSerialNumber2  = '6000c290666e1940815da4e1978e4aa2'                 # Target Disk Serial Number - ex: Log volume
$SourceVolumeName1        = 'vvol-aen-sql-25-a-1e763fbf-vg/Data-83782b36'      # Source volume name 1 on FlashArray - ex: Data volume
$SourceVolumeName2        = 'vvol-aen-sql-25-a-1e763fbf-vg/Data-49809d97'      # Source volume name 2 on FlashArray - ex: Log volume
$TargetVolumeName1        = 'vvol-aen-sql-25-b-8a8a2134-vg/Data-758b26fe'      # Target volume name 1 on FlashArray - ex: Data volume
$TargetVolumeName2        = 'vvol-aen-sql-25-b-8a8a2134-vg/Data-ee95fa49'      # Target volume name 2 on FlashArray - ex: Log volume



# Set Credentials - this assumes the same credential for the target SQL Server and the FlashArray
$Credential = Get-Credential



# Create a Powershell session against the target SQL Server
$TargetSession = New-PSSession -HostName $TargetSQLServer



# Offline the target database
$Query = "ALTER DATABASE [$DatabaseName] SET OFFLINE WITH ROLLBACK IMMEDIATE"
Invoke-Sqlcmd -ServerInstance $TargetSQLServer -Database master -Query $Query


# Offline the target volumes
Invoke-Command -Session $TargetSession -ScriptBlock { Get-Disk | Where-Object { $_.SerialNumber -eq $using:TargetDiskSerialNumber1 } | Set-Disk -IsOffline $True }
Invoke-Command -Session $TargetSession -ScriptBlock { Get-Disk | Where-Object { $_.SerialNumber -eq $using:TargetDiskSerialNumber2 } | Set-Disk -IsOffline $True }



# Connect to the FlashArray's REST API
$FlashArray = Connect-Pfa2Array –EndPoint $ArrayName -Credential $Credential -IgnoreCertificateError



# Create a new snapshot of the Protection Group
$Snapshot = New-Pfa2ProtectionGroupSnapshot -Array $FlashArray -SourceName $ProtectionGroupName



### Diagnostic 
# Validate that the correct volume(s) will be used from the protection group snapshot. 
# Note the final naming scheme of a protection group volume snapshot is
# [protection group name].[volume name]
# $Snapshot
# $Snapshot.Name + "." + $SourceVolumeName1
# $Snapshot.Name + "." + $SourceVolumeName2



# Perform the target volume overwrites
New-Pfa2Volume -Array $FlashArray -Name $TargetVolumeName1 -SourceName ($Snapshot.Name + "." + $SourceVolumeName1) -Overwrite $true 
New-Pfa2Volume -Array $FlashArray -Name $TargetVolumeName2 -SourceName ($Snapshot.Name + "." + $SourceVolumeName2) -Overwrite $true 



# Online the newly cloned volumes
Invoke-Command -Session $TargetSession -ScriptBlock { Get-Disk | Where-Object { $_.SerialNumber -eq $using:TargetDiskSerialNumber1 } | Set-Disk -IsOffline $False }
Invoke-Command -Session $TargetSession -ScriptBlock { Get-Disk | Where-Object { $_.SerialNumber -eq $using:TargetDiskSerialNumber2 } | Set-Disk -IsOffline $False }



# Online the database
$Query = "ALTER DATABASE [$DatabaseName] SET ONLINE WITH ROLLBACK IMMEDIATE"
Invoke-Sqlcmd -ServerInstance $TargetSQLServer -Database master -Query $Query


# Clean up
Remove-PSSession $TargetSession