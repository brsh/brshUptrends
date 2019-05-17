function Invoke-Uptrends {
	[CmdletBinding()]
	param (
		[string] $Sub,
		[pscredential] $Cred,
		[string] $Method = 'Get',
		$Body,
		[bool] $hardsetJson = $false
	)

	[string] $BaseURL = "https://api.uptrends.com/v4/${Sub}"

	$Call = @{
		UseBasicParsing = $true
		Credential      = $Cred
		URI             = $BaseURL
		Method          = $Method
	}

	if ($null -ne $Body) {
		$Call.Add('Body', $Body)
	}

	if ($hardsetJson) {
		$Call.Add('ContentType', 'application/json')
	}

	try {
		$response = Invoke-WebRequest @Call
		$retval = $response.content | ConvertFrom-Json
		$retval = $retval | ForEach-Object { $_ | Add-Member -MemberType NoteProperty -Name 'StatusCode' -Value $response.StatusCode; $_ }
		$retval
	} catch {
		if ($_.Exception.Response.StatusCode.value__ -ne 200) {
			[int] $ID = -1
			if ($null -ne ($_.Exception.Response.StatusCode.value__)) {
				try {
					$id = ($_.Exception.Response.StatusCode.value__) * -1
				} catch {
					$ID = -2
				}
			}
			new-object -TypeName PSObject -Property @{ ID = $ID; BaseURL = $BaseURL }
		} else {
			Write-Status 'Error calling the Uptrends API' -Type 'Error' -E $_
			Write-Status 'URL Requested:' -Type 'Info' -Level 2
			Write-Status "$BaseURL" -Type 'Info' -Level 3
		}
	}
}
