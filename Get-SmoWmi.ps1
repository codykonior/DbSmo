<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Get-SmoWmi {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    	$ComputerName
    )

    Begin {

    }

    Process {
        $cimSession = New-CimSessionDown -ComputerName $ComputerName
        $latestVersion = (Get-SmoWmiAssembly).Version

	    $knownPaths = @(
            (New-Object PSObject -Property @{ Version = 13; Path = "ROOT\Microsoft\SqlServer\ComputerManagement13" }),
            (New-Object PSObject -Property @{ Version = 12; Path = "ROOT\Microsoft\SqlServer\ComputerManagement12" }),
            (New-Object PSObject -Property @{ Version = 11; Path = "ROOT\Microsoft\SqlServer\ComputerManagement11" }),
            (New-Object PSObject -Property @{ Version = $latestVersion; Path = "ROOT\Microsoft\SqlServer\ComputerManagement10" }),
            (New-Object PSObject -Property @{ Version = $latestVersion;  Path = "ROOT\Microsoft\SqlServer\ComputerManagement" })
        )

        $foundPath = $null
        foreach ($knownPath in $knownPaths) {
            try {
                if (Get-CimClass -CimSession $cimSession -Namespace $knownPath.Path -ClassName __Namespace -Property Name) {
                    $foundPath = Get-SmoWmiAssembly -Version $knownPath.Version
                    break
                }
            } catch {
            }
        }

        if (!$foundPath) {
            Write-Error "Get-SmoWmi on $ComputerName could not find a working path to SQL Server WMI."
        }

	$foundPath

        if ($oldVersion = [AppDomain]::CurrentDomain.GetAssemblies() | Where { $_.ManifestModule.Name -eq "Microsoft.SqlServer.SqlWmiManagement.dll" } | Select -First 1) {
            if ($oldVersion.FullName -eq $foundPath.FullName) {
                Write-Verbose "Get-SmoWmi on $ComputerName found version $($foundPath.FullName) but it was already loaded."
            } else {
                Write-Error "Get-SmoWmi on $ComputerName found $($foundPath.FullName) but an old version was already loaded; $($oldVersion.FullName)."
            }
        } else {
                Write-Verbose "Get-SmoWmi on $ComputerName found $($foundPath.FullName)."
        }
    }

    End {

    }
}
