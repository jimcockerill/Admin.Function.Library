# Public\Add-BatchtoGroup.ps1

function Add-BatchtoGroup {
    <#
    .SYNOPSIS
        Brief description
    
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
        [string[]]$members,

        [Parameter(Mandatory = $false)]
        [string]$EntraName,

        [Parameter(Mandatory = $false)]
        [string]$EntraID
    )
    
    begin {
        Write-Verbose "Starting Get-UserData"
    }
    
    process {
        Write-Output "Processing user: $UserName"
        $requests = @()
        $requestId = 1
        if ($null -ne $EntraName) {$EntGrpID = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$($EntraName)'").value.ID}
        foreach ($member in $members) {
            $requests += @{
                id = "$requestId"
                method = "POST"
                url = "/groups/$($EntGrp.ID)/members/`$ref"
                body = @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($member.Id)"
                }
                headers = @{
                    "Content-Type" = "application/json"
                }
            }
            $requestId++
        }
        # Send batch request (max 20 per batch)
        $batchSize = 20
        for ($i = 0; $i -lt $requests.Count; $i += $batchSize) {
            $batch = $requests[$i..([Math]::Min($i + $batchSize - 1, $requests.Count - 1))]
            $batchBody = @{
                requests = $batch
            }
            $result = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/`$batch" -Body ($batchBody | ConvertTo-Json -Depth 10)
            Write-Host "Processed batch $([Math]::Floor($i / $batchSize) + 1)" -ForegroundColor Cyan
        }
    }
    
    end {
        Write-Verbose "Completed Get-UserData"
    }
}
