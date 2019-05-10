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
	$MaintWindow = @()

	if ((($null -eq $Name) -or ($Name.ToString().Length -eq 0)) -and ($null -ne $CurCred)) {
		$Name = (Request-uptMonitor -MonitorGuid $MonitorGuid -Credential $CurCred).Name
	}

	try {
		$all = Invoke-Uptrends -Sub $MW_url -Cred $CurCred
	} catch {
		Write-Status -Message 'Error calling for Maintenance Period' -type 'Error' -e $_
		Write-status -Message "Call was to: $MW_url" -type 'Info'

	}

	if (($null -eq $all) -or ($all.count -lt 1)) {
		if ($IncludeAllMonitors) {
			$retval = new-object -TypeName PSCustomObject -Property @{
				ID              = $null
				MaintenanceType = $null
				ScheduleMode    = $null
				Name            = $Name
				MonitorGUID     = $MonitorGUID
			}
			$retval.PSTypeNames.Insert(0, "brshUptrends.MaintenanceWindow")
			if ($ShowSummary) {
				$hash = @{
					MonitorGUID = $MonitorGUID
					Name        = $Name
					BaseURL     = $MW_url
				}
				#$hash.Period = $retval
				$obj = New-Object -TypeName PSCustomObject -Property $hash
				$obj.PSTypeNames.Insert(0, "brshUptrends.MaintenanceList")
				$obj
			} else {
				$retval
			}
		}
	} else {
		$all | ForEach-Object {
			try {
				$_ | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Name
				$_ | Add-Member -MemberType NoteProperty -Name 'MonitorGUID' -Value $MonitorGUID
				$_.PSTypeNames.Insert(0, "brshUptrends.MaintenanceWindow")
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
				$hash = @{
					MonitorGUID = $MonitorGUID
					Name        = $Name
					BaseURL     = $MW_url
				}
				if ($null -ne $_.BaseURL) {
					$hash.BaseURL = $_.BaseURL
				}
				$hash.Period = $retval

				if ($ShowSummary) {
					$obj = New-Object -TypeName PSCustomObject -Property $hash
					$obj.PSTypeNames.Insert(0, "brshUptrends.MaintenanceList")
					$obj
				} else {
					$retval
				}
			} catch {
				Write-Status -message 'Whoops!' -e $_ -Type 'Error'
			}
		}
	}
}


# function Get-Members {
# 	param (
# 		[string] $Description,
# 		[pscredential] $CurCred
# 	)
# 	write-host 'Get-Members helper!'
# 	if ($null -eq $script:CurrentGroups) {
# 		write-host 'Could not find cached groups'
# 		$groups = Request-uptGroup -Cred $CurCred -DoNotStoreGroups
# 		write-host "requested and found $($groups.count)"
# 		$groups = $groups | Where-Object { $_.Description -match $Description }
# 		write-host "filtered and found $($monitors.count)"

# 	} else {
# 		Write-Host 'Cached Groups found'
# 		$groups = Get-uptGroup -Filter $Description
# 	}
# 	if ($null -ne $groups) {
# 		#write-host $groups
# 		if ($null -eq $script:CurrentMembers) {
# 			$groups | Request-uptGroupMember -DoNotStoreMembers
# 		}
# 	}
# }
