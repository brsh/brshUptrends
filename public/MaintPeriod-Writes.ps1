function Add-uptMonitorMaintenancePeriod {
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[guid[]] $MonitorGUID,
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
		#https://www.uptrends.com/support/kb/api/maintenance-periods

		$MonitorGUID | ForEach-Object {
			Invoke-MPWrite -MonitorGUID $_ -Credential $CurCred -Method 'Post' -Body $MaintenancePeriod
		}
	}

	END { }
}

function Add-uptGroupMaintenancePeriod {
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
		#https://www.uptrends.com/support/kb/api/maintenance-periods

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
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
