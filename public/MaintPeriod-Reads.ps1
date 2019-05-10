function New-uptMaintenancePeriod {
	<#
	.SYNOPSIS
	Creates a hash of Maintenance Period Info

	.DESCRIPTION
	To create a Maintenance Period, you have to feed the API an properly formatted set of information.
	This function attempts to create that hash for you.

	.PARAMETER Start
	Parameter description

	.PARAMETER End
	Parameter description

	.PARAMETER Recurring
	Parameter description

	.PARAMETER DisableAlertsOnly
	Parameter description

	.EXAMPLE
	An example

	.LINK
	https://www.uptrends.com/support/kb/api/maintenance-periods

	.NOTES
	General notes
	#>

	[CmdletBinding(DefaultParameterSetName = 'OneTime')]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = 'OneTime')]
		[switch] $OneTime,
		[Parameter(Mandatory = $true, ParameterSetName = 'Daily')]
		[switch] $Daily,
		[Parameter(Mandatory = $true, ParameterSetName = 'Weekly')]
		[switch] $Weekly,
		[Parameter(Mandatory = $true, ParameterSetName = 'Monthly')]
		[switch] $Monthly,
		[Parameter(Mandatory = $true)]
		[datetime] $Start,
		[datetime] $End = (Get-Date).AddMinutes(60),
		[int] $Minutes,
		[int] $Hours,
		[Parameter(Mandatory = $true, ParameterSetName = 'Weekly')]
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					[System.Enum]::GetNames( [System.DayOfWeek] ) | ForEach-Object { if ($_ -match $WordToComplete) { $_ } }
				} else {
					[System.Enum]::GetNames( [System.DayOfWeek] )
				}
			})]
		[ValidateScript(
			{ [System.Enum]::GetNames( [System.DayOfWeek] ) -contains $_ }
		)
		]
		[string] $WeekDay = (get-date).ToString('dddd'),
		[Parameter(Mandatory = $true, ParameterSetName = 'Monthly')]
		[ValidateRange(1, 31)]
		[int] $MonthDay = (get-date).ToString('dd'),
		[switch] $DisableAlertsOnly = $false
	)

	[string] $Disable = 'DisableMonitoring'
	if ($DisableAlertsOnly) {
		$Disable = 'DisableNotifications'
	}

	[datetime] $CloseDate = $Start
	if ($PSBoundParameters.ContainsKey("Minutes")) {
		$CloseDate = $Start.AddMinutes($Minutes)
	} elseif ($PSBoundParameters.ContainsKey("Hours")) {
		$CloseDate = $Start.AddHours($Hours)
	} else {
		$CloseDate = $End
	}

	$hash = [ordered] @{
		ID              = 0
		MaintenanceType = $Disable
	}

	if ($OneTime) {
		$hash.Add('StartDateTime', $Start.ToString('O'))
		$hash.Add('EndDateTime', $CloseDate.ToString('O'))
		$hash.Add('ScheduleMode', 'OneTime')
	} elseif ($Daily) {
		$hash.Add('ScheduleMode', 'Daily')
		$hash.Add('StartTime', $Start.ToString('HH:mm'))
		$hash.Add('EndTime', $CloseDate.ToString('HH:mm'))
	} elseif ($Weekly) {
		$hash.Add('ScheduleMode', 'Weekly')
		$hash.Add('WeekDay', $WeekDay)
		$hash.Add('StartTime', $Start.ToString('HH:mm'))
		$hash.Add('EndTime', $CloseDate.ToString('HH:mm'))
	} elseif ($Monthly) {
		$hash.Add('ScheduleMode', 'Monthly')
		$hash.Add('MonthDay', $MonthDay)
		$hash.Add('StartTime', $Start.ToString('HH:mm'))
		$hash.Add('EndTime', $CloseDate.ToString('HH:mm'))
	}

	$hash
}

function Request-uptGroupMaintenancePeriod {
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param (
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'GUID', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('GUID')]
		[guid[]] $GroupGUID,
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Name', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false)]
		[Alias('MonitorGroupName')]
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-uptGroup -Filter "$WordToComplete").Description
				} else {
					(Get-uptGroup).Description
				}
			})]
		[string[]] $Description,
		[pscredential] $Credential,
		#[switch] $DoNotStorePeriods = $false,
		[switch] $ShowSummary,
		[switch] $IncludeAllMonitors
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
		if ($PsCmdlet.ParameterSetName -eq 'Name') {
			$GroupGUID = (Request-uptGroup -Filter $Description -DoNotStoreGroups).GroupGuid
		} elseif ($PsCmdlet.ParameterSetName -eq 'Default') {
			if ($null -ne $script:CurrentGroups) {
				$GroupGUID = (Get-uptGroup).GroupGuid
			} else {
				Write-Status -Message 'No Groups are saved in module memory' -Type 'Error'
				Write-Status -Message 'Run Request-uptGroup or supply a GroupGUID or Description' -Type 'Info' -Level 1
				$GroupGUID = $null
			}
		}

		if ($GroupGUID) {
			$GroupGUID | ForEach-Object {
				$Item = Request-uptGroupMember -GroupGUID $_ -Credential $CurCred -DoNotStoreMembers | Request-uptMonitorMaintenancePeriod -Credential $CurCred -ShowSummary:$ShowSummary -IncludeAllMonitors:$IncludeAllMonitors
				$Item
			}
		}
	}

	END { }
}

function Request-uptMonitorMaintenancePeriod {
	[CmdletBinding(DefaultParameterSetName = 'Default')]
	param (
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'GUID', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('GUID')]
		[guid[]] $MonitorGuid,
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'MonitorName', ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false)]
		[Alias('MonitorName')]
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					(Get-uptGroupMember -Filter "$WordToComplete").Name
				} else {
					(Get-uptGroupMember).Name
				}
			})]
		[string[]] $Name,
		[pscredential] $Credential,
		[switch] $ShowSummary,
		[switch] $IncludeAllMonitors
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
		if ($PsCmdlet.ParameterSetName -eq 'MonitorName') {
			$Name | ForEach-Object {
				if ($null -ne $script:CurrentMembers) {
					$MonitorGUID = (Get-uptGroupMember -Filter "$_").MonitorGUID
				} else {
					Write-Status -Message 'Using the Monitor name is only available if you cache the monitors' -Type 'Error'
					Write-Status -Message 'Run the Request-uptGroupMember function first' -level 1 -Type 'Info'
				}
			}
		}
		$MonitorGUID | ForEach-Object {
			Invoke-MPRead -MonitorGUID $_ -Credential $CurCred -ShowSummary:$ShowSummary -IncludeAllMonitors:$IncludeAllMonitors
		}
	}

	END { }
}

# function Get-uptMaintenancePeriod {
# 	param (
# 		[string] $Filter
# 	)
# 	if ($null -eq $script:MaintenancePeriods) {
# 		Write-Status -Message 'No MaintenancePeriods have been requested from Uptrends.' -Type 'Error' -Level 0
# 		Write-Status -Message 'Run Request-uptMaintenancePeriod to save a working set.' -Type 'Warning' -Level 1
# 	} else {
# 		if ($Filter) {
# 			$script:MaintenancePeriods | Where-Object { $_.Name -match "$Filter" }
# 		} else {
# 			$script:MaintenancePeriods
# 		}
# 	}
# }
