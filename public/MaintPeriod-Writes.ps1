function Add-uptMonitorMaintenancePeriod {
	<#
	.SYNOPSIS
	Add an MP to Monitor(s)

	.DESCRIPTION
	A function to add a pre-defined MaintenancePeriod object to one or several
	monitors. This works at the monitor level and is intended for the one- or
	few-offs that occur.

	If you need a quick way to set MPs on all Monitors in a Group, use the
	Add-uptGroupMaintenancePeriod function.

	.PARAMETER MonitorGUID
	The GUID of the monitor(s)

	.PARAMETER MaintenancePeriod
	The MP object created via New-uptMaintenancePeriod

	.PARAMETER Credential
	Credential for the API (unless already cached)

	.EXAMPLE
	$mp = New-uptMaintenancePeriod -Onetime -Start $((get-date).AddHours(2)) -Hours 2
	PS C:\>Add-uptMonitorMaintenancePeriod -MonitorGUID '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1' -MaintenancePeriod $mp

	Saves a new MP to the $mp variable and then adds it to the Monitor specified

	.LINK
	https://www.uptrends.com/support/kb/api/maintenance-periods
	#>

	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[guid[]] $MonitorGUID,
		[Parameter(Mandatory = $true)]
		[Alias('MP')]
		$MaintenancePeriod,
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
		$MonitorGUID | ForEach-Object {
			Invoke-MPWrite -MonitorGUID $_ -Credential $CurCred -Method 'Post' -Body $MaintenancePeriod
		}
	}

	END { }
}

function Add-uptGroupMaintenancePeriod {
	<#
	.SYNOPSIS
	Add a Maintenance Period to a Group(s)

	.DESCRIPTION
	The quickest way to add an MP to a lot of monitors: add it to the Group. The
	drawback ... Uptrends does not return anything other than a status code, so
	the only proof that it succeeds is a "quick" list of all MPs on the Group :(

	.PARAMETER GroupGUID
	The GUID(s) of th Group

	.PARAMETER MaintenancePeriod
	The MP object created via New-uptMaintenancePeriod

	.PARAMETER Credential
	Credential for the API (unless already cached)

	.EXAMPLE
	$mp = New-uptMaintenancePeriod -Onetime -Start $((get-date).AddHours(2)) -Hours 2
	PS C:\>Add-uptGroupMaintenancePeriod -GroupGUID '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1' -MaintenancePeriod $mp

	Saves a new MP to the $mp variable and then adds it to all Monitors in the Group(s) specified

	.LINK
	https://www.uptrends.com/support/kb/api/maintenance-periods
	#>

	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[guid[]] $GroupGUID,
		[Alias('MP')]
		$MaintenancePeriod,
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
		$GroupGUID | ForEach-Object {
			$retval = Invoke-MPWrite -GroupGUID $_ -Credential $CurCred -Method 'Post' -Body $MaintenancePeriod
			if ($retval.StatusCode -lt 300) {
				Request-uptGroupMaintenancePeriod -GroupGUID $_ -Credential $CurCred
			}
		}
	}

	END { }
}

function Edit-uptMaintenancePeriod {
	<#
	.SYNOPSIS
	Edit a setting on an existing MP

	.DESCRIPTION
	This function adjusts the settings of an MP - so you can change the end time,
	or the week day... whatever you need to change, you prolly can change it. The
	key pieces of information are the MonitorGUID, the MP ID, and the changes.

	And since MonitorGUID and MP ID are both required, it's best to pull the specific
	MP(s) you want via

		Request-uptMonitorMaintenancePeriod | where-object { $_.ID -eq ### }

	and then changing the approp property... and then using it in the command line.
	See the example for ... an example.

	.PARAMETER MaintenancePeriod
	The MP object created via New-uptMaintenancePeriod

	.PARAMETER Credential
	Credential for the API (unless already cached)

	.EXAMPLE
	$mp = Request-uptMonitorMaintenancePeriod -MonitorGUID '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1' | Where-Object { $_.ID -eq 503378 }
	PS C:\>$mp.WeekDay = 'Tuesday'
	PS C:\>Edit-uptMaintenancePeriod -MaintenancePeriod $mp

	.LINK
	https://www.uptrends.com/support/kb/api/maintenance-periods
	#>

	param (
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[ValidateScript( { $_.PSObject.TypeNames[0] -eq 'brshUptrends.MaintenancePeriod' })]
		[Alias('MP')]
		[PSCustomObject[]] $MaintenancePeriod,
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
		$MaintenancePeriod | ForEach-Object {
			$retval = Invoke-MPWrite -MonitorGUID $_.MonitorGUID -Credential $CurCred -Method 'Put' -Body $_

			if ($null -eq $retval.ID) {
				$ID = $_.ID
				Request-uptMonitorMaintenancePeriod -MonitorGUID $_.MonitorGUID -Credential $CurCred | Where-Object { $ID -eq $_.ID }
			} else {
				$retval
			}
		}
	}

	END { }
}

function Remove-uptMaintenancePeriod {
	<#
	.SYNOPSIS
	Detete an existing MP

	.DESCRIPTION
	This function deletes an MP - gone. Bye Bye.

	The key pieces of information are the MonitorGUID and the MP ID.

	And since MonitorGUID and MP ID are both required, it's best to pull the specific
	MP(s) you want via the Request-uptMonitorMaintenancePeriod function,
	and then using it in the command line. See the example for ... an example.

	.PARAMETER MaintenancePeriod
	The MP object created via New-uptMaintenancePeriod

	.PARAMETER Credential
	Credential for the API (unless already cached)

	.EXAMPLE
	$mp = Request-uptMonitorMaintenancePeriod -MonitorGUID '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1' | Where-Object { $_.ID -eq 503378 }
	PS C:\>Remove-uptMaintenancePeriod -MaintenancePeriod $mp

	Deletes MP with ID 503378

	.EXAMPLE
	$mp = Request-uptMonitorMaintenancePeriod -MonitorGUID '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1'
	PS C:\>Remove-uptMaintenancePeriod -MaintenancePeriod $mp

	Deletes all MPs on that Monitor

	.LINK
	https://www.uptrends.com/support/kb/api/maintenance-periods
	#>
	param (
		[Parameter(Mandatory = $true, position = 0, ValueFromPipeline = $true)]
		[ValidateScript( { $_.PSObject.TypeNames[0] -eq 'brshUptrends.MaintenancePeriod' })]
		[Alias('MP')]
		[PSCustomObject[]] $MaintenancePeriod,
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
		$MaintenancePeriod | ForEach-Object {
			Invoke-MPWrite -MonitorGUID $_.MonitorGUID -Credential $CurCred -Method 'Delete' -Body $_
		}
	}

	END { }
}
