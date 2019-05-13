function Request-uptGroup {
	<#
	.SYNOPSIS
	Pull a list of MonitorGroups from Uptrends

	.DESCRIPTION
	This function uses the API to pull a list of MonitorGroups from Uptrends - specifically, you
	need the GUID. You can set Maintenance Periods against an entire group, if you know the GUID.

	Alternatively, you can set an MW against a monitor, but you need the GUID of that monitor,
	which you can get by using the Request-uptGroupMember function ... as long as you
	know the MonitorGroup GUID. (Ok, I soften that need by caching requests... plus, you can
	always hard-code the guid in your scripts...).

	Note that you should provide appropriate credentials to access the API, but the function will
	ask for cred info if you don't. You can use the Set-uptStoredCredential for quick cred work.
	If you have stored a cred in the module's memory space, you do not need to specify the cred
	on the command line, and the function will not ask.

	.PARAMETER Credential
	Specify a credential variable for access to the Uptrends API

	.PARAMETER DoNotStoreGroups
	Just returns the list of MonitorGroups - does not cache the response

	.PARAMETER Filter
	Filters the list on specific text (and yes, regex works)

	.EXAMPLE
	Request-uptGroup

	Pulls a list of all MonitorGroups using credentials stored in the module memory space
	(or asks for cred information if no cred is saved)

	.EXAMPLE
	$cred = Get-Credential
	Request-uptGroup -Credential $cred

	Pulls a list of all MonitorGroups using credentials specified in $cred

	.EXAMPLE
	Request-uptGroup -Filter 'AA'

	Returns the list of MonitorGroups with AA in the name - anywhere (incl, say AtaAris)

	.EXAMPLE
	Request-uptGroup -Filter 'AA', 'BB'

	Returns the list of MonitorGroups with AA or BB in the name - anywhere (incl, say AtaAris)

	.EXAMPLE
	Request-uptGroup -Filter '^(AA|BB)'

	Returns the list of MonitorGroups that start with AA or BB
	#>

	param (
		[Parameter(Mandatory = $false, Position = 0)]
		[pscredential] $Credential,
		[string[]] $Filter,
		[switch] $DoNotStoreGroups = $false
	)

	[pscredential] $CurCred = $null
	if ($PSBoundParameters -contains $Credential) {
		$CurCred = $Credential
	} elseif ($null -ne $script:uptCred) {
		$CurCred = $script:uptCred
	} else {
		$CurCred = Set-uptStoredCredential -DoNotStoreCred
	}
	$all = Invoke-Uptrends -Sub 'MonitorGroup' -Cred $CurCred
	$all = $all | ForEach-Object {
		try {
			$GroupGUID = [guid] $_.MonitorGroupGUID
		} catch {
			$GroupGUID = $_.MonitorGroupGUID
		}
		$obj = new-object -TypeName PSCustomObject -Property @{
			Description = $_.Description
			GroupGUID   = $GroupGuid
		}
		$obj.PSTypeNames.Insert(0, "brshUptrends.Group")
		$obj
	}

	if ($Filter) {
		$AllFilt = @()
		$Filter | ForEach-Object {
			[string] $filt = $_
			$AllFilt += $all | Where-Object { $_.Description -match $filt }
		}
		$all = $AllFilt
	}

	if (-not $DoNotStoreGroups) {
		$script:CurrentGroups = $all
	}
	$all
}

function Get-uptGroup {
	param (
		[string] $Filter
	)
	## Note: This is here to make some auto-completion's easier
	## Assuming you have the group information cached.
	if ($Filter) {
		$script:CurrentGroups | Where-Object { $_.Description -match $Filter }
	} else {
		$script:CurrentGroups
	}
}

function Request-uptGroupMember {
	<#
.SYNOPSIS
Pulls a list of Monitor Groups from Uptrends

.DESCRIPTION
This function uses the API to pull a list of the Monitors in a Group from Uptrends - of course,
you need the Group's GUID. You pretty much need a GUID for everything. Get used to it.

You can set an MP against Group or, alternatively, you can set an MP against a monitor, but you
need the GUID of that Group or that Monitor, which you can get by using the Request-uptGroupMember
function ... as long as you know the Group GUID.

Note that you should provide appropriate credentials to access the API, but the function will
ask for cred info if you don't. You can use the Set-uptStoredCredential for quick cred work.
If you have stored a cred in the module's memory space, you do not need to specify the cred
on the command line, and the function will not ask.

.PARAMETER GroupGUID
The GUID(s) of the Group whose members you want to see

.PARAMETER MonitorGroupName
The Name(s) of the Group whose members you want to see (regex supported)

.PARAMETER Credential
Credential for the API (unless already cached)

.PARAMETER Filter
A filter for the Monitor names (regex supported)

.PARAMETER DoNotStoreMembers
Just returns the list of MonitorGroupMembers - does not cache the response

.EXAMPLE
Request-uptGroupMember

Pulls a list of all MonitorGroups using credentials stored in the module memory space
(or asks for cred information if no cred is saved)

.EXAMPLE
$cred = Get-Credential
PS C:\>Request-uptGroupMember -Credential $cred

Pulls a list of all MonitorGroups using credentials in $cred

.EXAMPLE
Request-uptGroupMember -MonitorGroupName '^AA', '^BB'

Pulls members from the MonitorGroups starting with those letters. This requires Request-uptGroup function be run first

.EXAMPLE
Request-uptGroupMember -GroupGuid '00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111'

Pulls members from the MonitorGroups with those GUIDs. This does not require any other Request-upt* function be run

.EXAMPLE
Request-uptGroup | Where-Object { $_.Description -match '^(AA|BB)' } | Request-uptGroupMember -DoNotStoreMembers -Filter 'www\.site\.tld'

Pulls Monitors with www.site.tld in the name in the groups whose descriptions start with AA or BB and does not cache the results
#>

	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param (
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'GUID', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('GUID')]
		[GUID[]] $GroupGUID,
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Name', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false)]
		[Alias('Description')]
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-uptGroup -Filter "$WordToComplete").Description
				} else {
					(Get-uptGroup).Description
				}
			})]
		[string[]] $MonitorGroupName,
		[Parameter(ParameterSetName = 'GUID')]
		[Parameter(ParameterSetName = 'Name')]
		[Parameter(ParameterSetName = 'Default')]
		[pscredential] $Credential,
		[Parameter(ParameterSetName = 'GUID')]
		[Parameter(ParameterSetName = 'Name')]
		[Parameter(ParameterSetName = 'Default')]
		[string[]] $Filter,
		[Parameter(ParameterSetName = 'GUID')]
		[Parameter(ParameterSetName = 'Name')]
		[Parameter(ParameterSetName = 'Default')]
		[switch] $DoNotStoreMembers = $false
	)
	BEGIN {
		$Members = @()
		[pscredential] $CurCred = $null
		if ($PSBoundParameters -contains $Credential) {
			$CurCred = $Credential
		} elseif ($null -ne $script:uptCred) {
			$CurCred = $script:uptCred
		} else {
			$CurCred = Set-uptStoredCredential -DoNotStoreCred
		}
	}

	PROCESS {
		if ($PsCmdlet.ParameterSetName -eq 'Name') {
			if ($null -eq $script:CurrentGroups) {
				$GroupGUID = (Request-uptGroup -DoNotStoreGroups -Credential $CurCred -Filter $MonitorGroupName).GroupGUID
			} else {
				$MonitorGroupName | ForEach-Object {
					$GroupGUID = (Get-uptGroup -Filter "$_").GroupGuid
				}
			}
		} elseif ($PsCmdlet.ParameterSetName -eq 'Default') {
			if ($null -ne $script:CurrentGroups) {
				$GroupGUID = (Get-uptGroup).GroupGuid
			}
		}

		foreach ($Group in $GroupGUID) {
			$all = Invoke-Uptrends -Sub "MonitorGroup/${Group}/Members" -Cred $CurCred
			$all | ForEach-Object {
				$GUID = $_.MonitorGuid
				if ($null -ne $GUID) {
					$Item = request-uptMonitor -Credential $CurCred -MonitorGUID $GUID
				}

				if ($Filter) {
					$Filter | ForEach-Object {
						[string] $filt = $_
						if ($Item.Name -match $filt) {
							$Members += $Item
							$Item
						}
					}
				} else {
					$Members += $Item
					$Item
				}

			}
		}
	}

	END {
		if (-not $DoNotStoreMembers) {
			$script:CurrentMembers = $Members
		}
	}
}

function Request-uptMonitor {
	#Really, you almost never run this manually. I will prolly move it to private someday
	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[guid[]] $MonitorGuid,
		[pscredential] $Credential
	)
	BEGIN {
		[pscredential] $CurCred = $null
		if ($PSBoundParameters -contains $Credential) {
			$CurCred = $Credential
		} elseif ($null -ne $script:uptCred) {
			$CurCred = $script:uptCred
		} else {
			$CurCred = Set-uptStoredCredential -DoNotStoreCred
		}
	}

	PROCESS {
		$Item = Invoke-Uptrends -Sub "Monitor/$MonitorGuid" -Cred $CurCred
		$Item | ForEach-Object {
			try {
				$holdGUID = [guid] $_.MonitorGUID
			} catch {
				$holdGUID = $_.MonitorGUID
			}
			$obj = new-object -TypeName PSCustomObject -Property @{
				MonitorGUID = $holdGUID
				Name        = $_.Name
				IsActive    = $_.IsActive
			}
			$obj.PSTypeNames.Insert(0, "brshUptrends.Monitor")
			$obj
		}
	}
}

function Get-uptGroupMember {
	## Note: This is here to make some auto-completion's easier
	## Assuming you have the monitor information cached.
	param (
		[string] $Filter
	)
	if ($Filter) {
		$script:CurrentMembers | Where-Object { $_.Name -match "$Filter" }
	} else {
		$script:CurrentMembers
	}
}

