<#  
.SYNOPSIS  
	Create database snapshot based on original filenames
.PARAMETER SQLServerInstanceName
	Name of the SQL Server instance
.PARAMETER DatabaseName
	Name of the source database
.PARAMETER DatabaseSnapshotName
	Name of the database snapshot
.PARAMETER DropExisting
	Specify to drop the database snapshot if it already exists
EXAMPLE
	Create-SqlSnapshot.ps1 localhost" "AdventureWorks2012" "AdventureWorks2012_Snap" -DropExisting
.NOTES
	Version		: 1.0
	Author		: Gianluca Hotz - gianluca_hotz@hotmail.com
	Copyright	: (c) 2014, Gianluca Hotz (BSD 3-clause license)
.LINK
	http://www.ghotz.com
#>

param
( 	
	[Parameter(Mandatory=$True, Position=1)]
	[string]$SQLServerInstanceName,
	[Parameter(Mandatory=$True,Position=2)]
	[string]$DatabaseName,
	[Parameter(Mandatory=$True,Position=3)]
	[string]$DatabaseSnapshotName,
	[switch]$DropExisting
);
#region functions
	function Get-SQLInstance($InstanceName, $Login, $Password)
	{
		$SQLInstance = New-Object "Microsoft.SqlServer.Management.Smo.Server" $InstanceName;
		if ($Login -eq $null) {
			$SQLInstance.ConnectionContext.LoginSecure = $true;
		}
		else {
			$SQLInstance.ConnectionContext.LoginSecure = $false;
			$SQLInstance.ConnectionContext.Login = $Login;
			$SQLInstance.ConnectionContext.Password = $Password;
		};
		# Force connection to get an early error message
		$SQLInstance.ConnectionContext.Connect();
		return $SQLInstance;
	};
#endregion functions
#region main
[Void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO');
[Void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended');

# connect and get database
$SQLInstance = Get-SQLInstance $SQLServerInstanceName;
$Database = $SQLInstance.Databases[$DatabaseName];

if ($Database -eq $null)
{
	Write-Host "Database [$DatabaseName] does not exists";
	return;
};

# drop or create snapshot database
if ($SQLInstance.Databases[$DatabaseSnapshotName] -ne $null)
{
	if ($DropExisting)
	{
		$SQLInstance.Databases[$DatabaseSnapshotName].Drop();
	}
	else
	{
		Write-Host "Database snapshot [$DatabaseSnapshotName] already esists, specify DropExisting parameter to drop & re-create.";
		return;
	};
};

# create database snapshot object
$DatabaseSnapshot = New-Object ("Microsoft.SqlServer.Management.Smo.Database") ($SQLServerInstanceName, $DatabaseSnapshotName);
$DatabaseSnapshot.DatabaseSnapshotBaseName = $DatabaseName;

# for each filegroup in source database
foreach ($FileGroup in $Database.FileGroups)
{
	# add a filegroup to the snapshot with the same source name
	$DatabaseSnapshotFileGroup = New-Object ("Microsoft.SqlServer.Management.Smo.FileGroup") ($DatabaseSnapshot, $FileGroup.Name);
	$DatabaseSnapshot.FileGroups.Add($DatabaseSnapshotFileGroup);
	
	# for each data file in the source filegroup
	foreach ($DataFile in $FileGroup.Files)
	{
		# add a data file to the snapshot with the same name and the same filename extended with ".ss"
		$DatabaseSnapshotDataFile = New-Object ("Microsoft.SqlServer.Management.Smo.DataFile") ($DatabaseSnapshotFileGroup, $DataFile.Name, ($DataFile.Filename + ".ss"));
		$DatabaseSnapshotFileGroup.Files.Add($DatabaseSnapshotDataFile);
	};
};

# create the database snapshot
$DatabaseSnapshot.Create();
#endregion main