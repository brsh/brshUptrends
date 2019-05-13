function New-uptMaintenancePeriod {
	<#
.SYNOPSIS
Creates a hash of Maintenance Period Info

.DESCRIPTION
To create a Maintenance Period, you have to feed the API a properly formatted
set of information. This function... creates that info for you.

The types of Maintenance Periods are:
	OneTime - only happen once and never again
	Daily   - happen daily at the same time each day
	Weekly  - happen once a week on the same day and same time
	Monthly - happen once a month, on a specific day of the month

Depending on the type of MP, you'll need to specify either the WeekDay or the
MonthDay when the MP should occur.

The Start date/time is the only one you really need to specify as a date. You
can specify and End date/time, or how many minutes or how many hours the MP
should last.

Finally, MPs can DisableAlertsOnly or, by default, it will disable Alerts
AND Monitoring. If you're really working on the system, you'll prolly want to
use the default and disable all Monitoring. But, sometimes, you want the
Monitors to continue, but you just don't care to hear about it. Your choice.

.PARAMETER OneTime
This is a OneTime MP

.PARAMETER Daily
This is a Daily MP

.PARAMETER Weekly
This is a Weekly MP

.PARAMETER Monthly
This is a Monthly MP

.PARAMETER Start
The Start date time for the MP

.PARAMETER End
The End data time for the MP

.PARAMETER Minutes
How many minutes the MP should last

.PARAMETER Hours
How many hours the MP should last

.PARAMETER WeekDay
Which day of the week a Weekly MP should run

.PARAMETER MonthDay
Which day of the month a Monthly MP should run (exampl, 19 [the 19th day] - or 5 [the 5th day])

.PARAMETER DisableAlertsOnly
Default, All Monitoring will be stopped. This will keep Monitoring active; it just won't alert

.EXAMPLE
$b = New-uptMaintenancePeriod -OneTime -Start '5/22/2019 7pm' -Hours 2 -DisableAlertsOnly
PS> $b

Name                           Value
----                           -----
ID                             0
MaintenanceType                DisableNotifications
StartDateTime                  2019-05-22T19:00:00.0000000
EndDateTime                    2019-05-22T21:00:00.0000000
ScheduleMode                   OneTime

.EXAMPLE
$b =  New-uptMaintenancePeriod -Weekly -Start '5/22/2019 7pm' -Hours 2 -WeekDay Tuesday
PS> $b

Name                           Value
----                           -----
ID                             0
MaintenanceType                DisableMonitoring
ScheduleMode                   Weekly
WeekDay                        Tuesday
StartTime                      19:00
EndTime                        21:00
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
	<#
	.SYNOPSIS
	Query the API for MPs for all monitors in a group

	.DESCRIPTION
	This is the big one - by default, showing any and all MPs defined for all the Monitors
	in a Group (yep, skipping Monitors without MPs). You can use the -IncludeAllMonitors,
	if you want, to include monitors without MPs - that's handy to see what does and
	does _not_ have MPs.

	The default view (in table format) is a stylized view of the MPs. OneTime MPs have
	different properties than Daily/Weekly/Monthly monitors, so the stylized view "unites"
	the properties so they're easier to peruse. The actual properties on the objects are
	a little different, but accessible via Format-List or Select-Object cmdlets.

	There is also a 'ShowSummary' switch, which is a more Monitor view of the data; it
	groups the MPs by Monitor, showing just base MP information.

	.PARAMETER GroupGUID
	The GUID(s) of the Group to show

	.PARAMETER Description
	The Description of the Group to show (slower, since we'll have to query all groups to get their names)

	.PARAMETER Credential
	Credential for the API (unless already cached)

	.PARAMETER ShowSummary
	Show MP summaries grouped by Monitor

	.PARAMETER IncludeAllMonitors
	Show all monitors - even those without MPs

	.EXAMPLE
	Request-uptGroup -Filter 'AA', 'BB' | Request-uptGroupMaintenancePeriod

	Shows MPs for all Monitors in AA and BB groups
	#>

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
	<#
	.SYNOPSIS
	Query the API for MPs on specific Monitors

	.DESCRIPTION
	This is the heavy lifter - this queries the API for MPs on specific Monitors - preferably
	by MonitorGUID, but you can use the name if you cache them ahead of time. Frankly, you'll
	use groups or scripts, so Monitor Names aren't really that important.

	Just like the Request-uptGroupMaintenancePeriod function, this function, by default, will
	not include Monitors that do not have MPs defined. You can use the -IncludeAllMonitors,
	if you want, to include monitors without MPs - that's handy to see what does and
	does _not_ have MPs.

	The default view (in table format) is a stylized view of the MPs. OneTime MPs have
	different properties than Daily/Weekly/Monthly monitors, so the stylized view "unites"
	the properties so they're easier to peruse. The actual properties on the objects are
	a little different, but accessible via Format-List or Select-Object cmdlets.

	There is also a 'ShowSummary' switch, which is a more Monitor view of the data; it
	groups the MPs by Monitor, showing just base MP information.

	.PARAMETER MonitorGuid
	The GUID(s) of the Monitors to get

	.PARAMETER Name
	The name(s) of the Monitors to query (regex capable); Monitors must be cached first

	.PARAMETER Credential
	Credential for the API (unless already cached)

	.PARAMETER ShowSummary
	Show MP summaries grouped by Monitor

	.PARAMETER IncludeAllMonitors
	Show all monitors - even those without MPs

	.EXAMPLE
	Request-uptMonitorMaintenancePeriod -MonitorGuid '76c69d9f-05a7-4e8e-a6cc-7c6dc17538f1', '4b422f94-36a0-470d-ae7e-641e91b02ccc'

	Returns the MPs attached to the Monitors with those GUIDs (assuming there are MPs on those Monitors)
	#>

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
