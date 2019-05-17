function Invoke-MPRead {
	param (
		[string] $MonitorGUID,
		[string] $Name,
		[pscredential] $Credential,
		[switch] $ShowSummary,
		[switch] $IncludeAllMonitors
	)

	[pscredential] $CurCred = $null
	if ($PSBoundParameters -contains $Credential) {
		$CurCred = $Credential
	} elseif ($null -ne $script:uptCred) {
		$CurCred = $script:uptCred
	}

	$MW_url = "Monitor/${MonitorGUID}/MaintenancePeriod"
	$MaintPeriod = @()

	if ((($null -eq $Name) -or ($Name.ToString().Length -eq 0)) -and ($null -ne $CurCred)) {
		$Name = (Request-uptMonitor -MonitorGuid $MonitorGuid -Credential $CurCred).Name
	}

	try {
		$all = Invoke-Uptrends -Sub $MW_url -Cred $CurCred
	} catch {
		Write-Status -Message 'Error calling for Maintenance Period' -type 'Error' -e $_
		Write-status -Message "Call was to: $MW_url" -type 'Info'

	}
	if ($null -eq $all) {
		if ($IncludeAllMonitors) {
			$retval = new-object -TypeName PSCustomObject -Property @{
				ID              = $null
				MaintenanceType = $null
				ScheduleMode    = $null
				Name            = $Name
				MonitorGUID     = $MonitorGUID
			}
			$retval.PSTypeNames.Insert(0, "brshUptrends.MaintenancePeriod")
			if ($ShowSummary) {
				$hash = @{
					MonitorGUID = $MonitorGUID
					Name        = $Name
					BaseURL     = $MW_url
				}
				$obj = New-Object -TypeName PSCustomObject -Property $hash
				$obj.PSTypeNames.Insert(0, "brshUptrends.MaintenanceList")
				$obj
			} else {
				$retval
			}
		}
	} else {
		$hash = @{
			MonitorGUID = $MonitorGUID
			Name        = $Name
			BaseURL     = $MW_url
		}
		if ($null -ne $_.BaseURL) {
			$hash.BaseURL = $_.BaseURL
		}
		$all | ForEach-Object {
			try {
				$_ | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Name
				$_ | Add-Member -MemberType NoteProperty -Name 'MonitorGUID' -Value $MonitorGUID
				$_.PSTypeNames.Insert(0, "brshUptrends.MaintenancePeriod")
				$retval = $_
				if ($retval.ID) {
					$retval | Add-Member -MemberType NoteProperty -Name 'ID' -Value ([int] $_.ID) -Force
				}
				if ($retval.StartDateTime) {
					$retval | Add-Member -MemberType NoteProperty -Name 'StartDateTime' -Value ([datetime] $_.StartDateTime) -Force
				}
				if ($retval.StartTime) {
					$retval | Add-Member -MemberType NoteProperty -Name 'StartTime' -Value ([datetime] $_.StartTime) -Force
				}
				if ($retval.EndDateTime) {
					$retval | Add-Member -MemberType NoteProperty -Name 'EndDateTime' -Value ([datetime] $_.EndDateTime) -Force
				}
				if ($retval.EndTime) {
					$retval | Add-Member -MemberType NoteProperty -Name 'EndTime' -Value ([datetime] $_.EndTime) -Force
				}


				if (($_.ID -lt 0) -or ($null -eq $_.ID)) {
					if ($null -eq $_.ID) {
						$hold = '-9999'
					} else {
						$hold = $_.ID
					}
					$retval = , "None Defined ($hold)"
				}
				$MaintPeriod += $retval

				if (-not $ShowSummary) { $retval }
			} catch {
				Write-Status -message 'Whoops!' -e $_ -Type 'Error'
			}
		}
		if ($ShowSummary) {
			$hash.Period = $MaintPeriod
			$obj = New-Object -TypeName PSCustomObject -Property $hash
			$obj.PSTypeNames.Insert(0, "brshUptrends.MaintenanceList")
			$obj
		}
	}
}

function Invoke-MPWrite {
	param (
		[parameter(ParameterSetName = 'Monitor')]
		[guid] $MonitorGUID,
		#[string] $Name,
		[parameter(ParameterSetName = 'Group')]
		[guid] $GroupGUID,
		[pscredential] $Credential,
		$body,
		[Microsoft.Powershell.Commands.WebRequestMethod] $Method
	)

	[pscredential] $CurCred = $null
	if ($PSBoundParameters -contains $Credential) {
		$CurCred = $Credential
	} elseif ($null -ne $script:uptCred) {
		$CurCred = $script:uptCred
	}

	[string] $MW_url = "MonitorGroup/${GroupGUID}/MaintenancePeriod"
	if ((($null -eq $Name) -or ($Name.ToString().Length -eq 0)) -and ($null -ne $CurCred)) {
		if ($PSCmdlet.ParameterSetName -eq 'Monitor') {
			$Name = (Request-uptMonitor -MonitorGuid $MonitorGuid -Credential $CurCred).Name
			$MW_url = "Monitor/${MonitorGUID}/MaintenancePeriod"
		}
	}


	[bool] $hardsetJson = $false

	$teMP = $body

	if ($Method -eq 'Post') {
		$teMP = ConvertTo-MPHash -MP $body
		$hardsetJson = $true
	} elseif ($Method -eq 'Put') {
		$MW_url = "$MW_url/$($body.ID)"
		$teMP = ConvertTo-MPHash -MP $body
		$hardsetJson = $true
	} elseif ($Method -eq 'Delete') {
		$MW_url = "$MW_url/$($body.ID)"
	}

	try {
		$all = Invoke-Uptrends -Sub $MW_url -Cred $CurCred -Body $teMP -Method $Method -hardsetJson:$hardsetJson
	} catch {
		Write-Status -Message 'Error calling for Maintenance Period' -type 'Error' -e $_
		Write-status -Message "Call was to: $MW_url" -type 'Info'
	}
	if ($null -ne $All) {
		$all = Add-Attributes -Stuff $all -Name $name -MonitorGUID $MonitorGUID
	}
	$all
}

function Add-Attributes {
	param (
		$stuff,
		$name,
		$MonitorGUID
	)
	$stuff | ForEach-Object {
		$_ | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Name
		$_ | Add-Member -MemberType NoteProperty -Name 'MonitorGUID' -Value $MonitorGUID
		$_.PSTypeNames.Insert(0, "brshUptrends.MaintenancePeriod")
		$retval = $_
		if ($retval.ID) {
			$retval | Add-Member -MemberType NoteProperty -Name 'ID' -Value ([int] $_.ID) -Force
		}
		if ($retval.StartDateTime) {
			$retval | Add-Member -MemberType NoteProperty -Name 'StartDateTime' -Value ([datetime] $_.StartDateTime) -Force
		}
		if ($retval.StartTime) {
			$retval | Add-Member -MemberType NoteProperty -Name 'StartTime' -Value ([datetime] $_.StartTime) -Force
		}
		if ($retval.EndDateTime) {
			$retval | Add-Member -MemberType NoteProperty -Name 'EndDateTime' -Value ([datetime] $_.EndDateTime) -Force
		}
		if ($retval.EndTime) {
			$retval | Add-Member -MemberType NoteProperty -Name 'EndTime' -Value ([datetime] $_.EndTime) -Force
		}
	}
	$stuff
}

function ConvertTo-MPHash {
	param (
		$MP
	)

	[bool] $DisableAlertsOnly = Switch ($MP.MaintenanceType) {
		'DisableMonitoring' { $false; break }
		'DisableNotifications' { $true; break }
	}

	$hash = @{
		DisableAlertsOnly = $DisableAlertsOnly
		Start             = $MP.StartTime
		End               = $MP.EndTime
	}

	if ($MP.IP) { $hash.add('ID', $MP.ID) }

	Switch ($MP.ScheduleMode) {
		'OneTime' {
			$hash.Start = $MP.StartDateTime
			$hash.End = $MP.EndDateTime
			New-uptMaintenancePeriod -OneTime @hash | ConvertTo-Json
			break
		}
		'Daily' {
			New-uptMaintenancePeriod -Daily @hash | ConvertTo-Json
			break
		}
		'Weekly' {
			New-uptMaintenancePeriod -Weekly -Weekday $MP.Weekday @hash | ConvertTo-Json
			break
		}
		'Monthly' {
			New-uptMaintenancePeriod -Monthly -MonthDay $MP.MonthDay @hash | ConvertTo-Json
			break
		}
	}








}
