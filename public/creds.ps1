function Set-uptStoredCredential {
	<#
.SYNOPSIS
Creates a credential object to connect to the API

.DESCRIPTION
Basically, this just creates a credential object - you can do the same thing with
the Get-Credential cmdlet (and don't let me stop you). This function is just an
attempt to encapsulate options - like using a SecureToken, if you have that module
and have saved your api username and password with it.

By default, this function will save the cred in memory for use automatically with
the API calls. You can use the DoNotStoreCred if you want to create a cred and
assign it to a variable that you use. Your call. Again, you can also create your
own cred your own way and use it in these functions. Who am I to tell you what
to do?

.PARAMETER UserName
The plain text "username" for the API. If not provided, the script will ask

.PARAMETER Password
The plain text "password" for the API. If not provided, the script will ask

.PARAMETER PasswordSecure
You can create your own SecureString variable and pass it thru.
Either way is fine with me.

.PARAMETER SecureTokenUserName
If you have the SecureToken module, you can ref the approps UserName token here

.PARAMETER SecureTokenPasswordName
If you have the SecureToken module, you can ref the approps Password token here

.PARAMETER DoNotStoreCred
Outputs a cred for saving to your own variable. This will also clear any cred
stored in memory

.EXAMPLE
Set-StoredCredential
Please enter you Uptrends' API UserName
API UserName : dfdd
Please enter you Uptrends' API Password
Password : *****

Stores a cred for use with the Uptrends API functions

.EXAMPLE
Set-StoredCredential -UserName 0000d0031 -Password ssss0ddft

Stores a cred for use with the Uptrends API functions

.EXAMPLE
$a = Read-Host -AsSecureString
PS C:\>Set-StoredCredential -UserName 0000d0031 -Password $a

Creates a securestring and uses that in the stored cred for use with the Uptrends API functions

.EXAMPLE
Set-uptStoredCredential -SecureTokenUserName UptrendsAPIUserName -SecureTokenPasswordName UptrendsAPIPassword

Stores a cred using the supplied SecureTokens

.EXAMPLE
$cred = Set-uptStoredCredential -DoNotStoreCred
Please enter you Uptrends' API UserName
API UserName : dfdd
Please enter you Uptrends' API Password
Password : *****

Assigns the cred to the var $cred. This does not store a cred in module memory
#>

	[CmdletBinding(DefaultParameterSetName = 'Text')]
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
	param (
		[Parameter(Mandatory = $false, ParameterSetName = 'Text')]
		[Parameter(Mandatory = $false, ParameterSetName = 'SecureText')]
		[string] $UserName,
		[Parameter(Mandatory = $false, ParameterSetName = 'Text')]
		[string] $Password,
		[Parameter(Mandatory = $false, ParameterSetName = 'SecureText')]
		[securestring] $PasswordSecure,
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					Get-SecureTokenList -Filter "$WordToComplete"
				} else {
					Get-SecureTokenList
				}
			})]
		[Parameter(Mandatory = $false, ParameterSetName = 'SecureToken')]
		[string] $SecureTokenUserName,
		[ArgumentCompleter( {
				param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
				if ($WordToComplete) {
					Get-SecureTokenList -Filter "$WordToComplete"
				} else {
					Get-SecureTokenList
				}
			})]
		[Parameter(Mandatory = $false, ParameterSetName = 'SecureToken')]
		[string] $SecureTokenPasswordName,
		[switch] $DoNotStoreCred = $false
	)
	[bool] $DoIt = $true

	if (($PsCmdlet.ParameterSetName -eq 'text') -or ($PsCmdlet.ParameterSetName -eq 'SecureText')) {
		if ($UserName.Length -lt 1) {
			do {
				write-host "Please enter you Uptrends' API UserName" -ForegroundColor Yellow
				[string] $string = 'API UserName '
				$UserName = Read-Host -Prompt $string
			} while ($Username.Length -lt 1)
		}
	}
	if ((($PsCmdlet.ParameterSetName -eq 'text') -and ($Password.Length -lt 1)) -or (($PsCmdlet.ParameterSetName -eq 'SecureText') -and ($PasswordSecure.Length -lt 1))) {
		do {
			write-host "Please enter you Uptrends' API Password" -ForegroundColor Yellow
			$PasswordSecure = Read-Host 'Password ' -AsSecureString
		} while ($PasswordSecure.Length -lt 1)
	}

	if (($PsCmdlet.ParameterSetName -eq 'text') -and ($Password.Length -gt 0)) {
		$PasswordSecure = ConvertTo-SecureString -AsPlainText -Force -String $Password
	}

	if ($PsCmdlet.ParameterSetName -eq 'SecureToken') {
		if ($script:UseSecureToken) {
			$UserNameToken = (Get-SecureToken -Name $SecureTokenUserName).Token
			if ($UserNameToken -ne 'Not Found') {
				$UserName = $UserNameToken
			} else {
				Write-Status -Message "SecureToken $SecureTokenUserName for API UserName not found." -Type 'Warning'
			}
			$PasswordToken = (Get-SecureToken -Name $SecureTokenPasswordName).Token
			if ($PasswordToken -ne 'Not Found') {
				$PasswordSecure = ConvertTo-SecureString -AsPlainText -Force -String $PasswordToken
			} else {
				Write-Status -Message "SecureToken $SecureTokenUserName for API Password not found." -Type 'Warning'
			}
			if (($UserNameToken -eq 'Not Found') -or ($PasswordToken -eq 'Not Found')) {
				$DoIt = $false
			}
		} else {
			Write-Status -Message 'SecureTokens are not available.' -Type 'Error'
			$DoIt = $false
		}
	}

	if ($DoIt) {
		try {
			[pscredential] $NewCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $PasswordSecure
		} catch {
			Write-Status -Message 'Unable to create/store credential' -Type 'Error' -E $_
		}

		if ($DoNotStoreCred) {
			if ($null -ne $NewCred) {
				$NewCred
				$script:uptCred = $null
			}
		} else {
			$script:uptCred = $NewCred
			Write-Status -Message 'Credential saved in memory' -Type 'Good'
		}

	}
}
