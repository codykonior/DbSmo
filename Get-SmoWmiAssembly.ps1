<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Get-SmoWmiAssembly {
    [CmdletBinding(DefaultParameterSetName = "Latest")]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Downgrade")]
    	$DowngradeFrom,
        [Parameter(Mandatory = $true, ParameterSetName = "Exact")]
	    $Version,
        [Parameter(ParameterSetName = "Latest")]
	    [switch] $Latest
    )

    Begin {

    }

    Process {
    	$assemblies = Get-ChildItem "C:\Windows\Assembly\GAC_MSIL\Microsoft.SqlServer.SqlWmiManagement" "Microsoft.SqlServer.SqlWmiManagement.dll" -Recurse | 
			Sort { $_.VersionInfo.ProductVersion } -Desc | %{
    	        New-Object PSObject -Property @{ 
                    Version = $_.VersionInfo.ProductMajorPart
                    FullName = [System.Reflection.AssemblyName]::GetAssemblyName($_.FullName).FullName 
                    Path = $_.FullName
                }
            }
        if (!$assemblies) {
		    Write-Error "Get-SmoWmiAssembly could not find any SMO WMI assemblies to use."
    	}
        if ($DowngradeFrom) {
			$nextAssembly = $assemblies | Where { $_.Version -lt $DowngradeFrom.Version } | Select -First 1

			if (!$nextAssembly) {
				Write-Verbose "Get-SmoWmiAssembly could not find a ower version of SMO WMI to downgrade to."
				return
			}
        } elseif ($Version) {
		    $nextAssembly = $assemblies | Where { $_.Version -eq $Version } | Select -First 1
	    } else {
            $nextAssembly = $assemblies | Select -First 1
        }

    	Write-Verbose "Get-SmoWmiAssembly found version $($nextAssembly.Version) with full name `"$($nextAssembly.FullName)`" at $($nextAssembly.Path)"
	    $nextAssembly
    }

    End {

    }
}
