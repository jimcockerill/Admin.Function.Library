# Public\Get-ScopedDevices.ps1

function Get-ScopedDevices {
    <#
    .SYNOPSIS
    
    .DESCRIPTION
        Detailed description
    
    .PARAMETER UserName
        Description of parameter
    
    .EXAMPLE
        Get-UserData -UserName "JohnDoe"
    
    .NOTES
        Author: Your Name
        Date: 2024-11-28
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$groupArray
    )
    
    begin {
        Write-Verbose "Starting Get-ScopedDevices"
        $i = 0
        $proceed = $true
        $Count = $groupArray.Count
        $entraDevs = [System.Collections.Generic.List[object]]::new()
        $placeholderDate = [datetime]"2000-01-01T00:00:00"
        $outPath = "C:\ProgramData\Sky\Cache\Cloud"
        $jsonOut = "Dev_Ent.json"
        if (!(Test-Path -Path $outPath)) {New-Item -Path $outPath -ItemType Directory -Force}
        $discoverFile = Get-Item "$outPath\$jsonOut" -ErrorAction SilentlyContinue
    }
    
    process {
        if ($null -ne $discoverFile) {
            if ($discoverFile.CreationTime -lt (Get-Date).AddHours(-24)) {
                Write-Host "Aged Entra Device export discovered, removing file."
                Remove-Item -Path "$outPath\$jsonOut" -Force
            } else {
                Write-Host "Current Entra Device export discovered, exporting content."
                $proceed = $false
            }
        }

        if ($proceed) {
            #Collecting devices from each group within group array
            Write-Host "Collecting in-scope device details"
            foreach ($grp in $groupArray) {
                $i++
                Write-Host "$i of $Count"
                <#$result = Invoke-MgGraphTask -Method 'Get' -Version 'v1.0' -Resource "groups/$($grp.id)/members"
                if ($result) {
                    $entraDevs.AddRange($result)
                }#>

                try {
                    $result = Invoke-MgGraphTask -Method 'Get' -Version 'v1.0' -Resource "groups/$($grp.id)/members"
                    if ($result) {
                        $entraDevs.AddRange([array]$result)
                    }
                }
                catch {
                    Write-Warning "Failed to retrieve members from group '$($grp.displayName)' ($($grp.id)): $_"
                }
            }

            # Array normalization
            Write-Host "Normalizing device array"
            $entraDevs = $entraDevs | Where-Object {$_.'@odata.context' -ne 'https://graph.microsoft.com/v1.0/$metadata#directoryObjects'}
            foreach ($device in $entraDevs) {
                if ($null -eq $device.approximateLastSignInDateTime) {
                    $device.approximateLastSignInDateTime = $placeholderDate
                }
            }

            # Deduplicate using hashtable
            Write-Host "Deduplicating device array"
            $deviceHash = @{}
            foreach ($device in $entraDevs) {
                $key = $device.displayName
                if (-not $deviceHash.ContainsKey($key) -or 
                    $device.approximateLastSignInDateTime -gt $deviceHash[$key].approximateLastSignInDateTime) {
                    $deviceHash[$key] = $device
                }
            }
            $deduplicatedArray = @($deviceHash.Values)
        }
    }

    end {
        Write-Verbose "Completed Get-ScopedDevices"
        if ($proceed) {
            $deduplicatedArray | ConvertTo-Json -Depth 5 | Out-File "$outPath\$jsonOut"
            return $deduplicatedArray
        } else {
            return (Get-Content "$outPath\$jsonOut" -Raw | ConvertFrom-Json)
        }
        
    }
}    