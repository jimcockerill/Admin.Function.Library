# Public\Invoke-MgGraphTask.ps1

function Invoke-MgGraphTask {
    [CmdletBinding()]
    param(
        [ValidateSet("Get", "Post", "Delete", "Put", "Patch")]
        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$Resource,

        [Parameter(Mandatory = $false)]
        [string]$Extra,

        [Parameter(Mandatory = $false)]
        [string]$Body,

        [Parameter(Mandatory = $false)]
        [string]$OutputFilePath
    )

    begin {
        Write-Verbose "Starting Microsoft Graph API call"
        
        ## Verify MS Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to MS Graph. Please run Connect-MgGraph."
        }
    }
    
    process {
        try {
            # Use List for efficient array building
            $GrRaw = [System.Collections.Generic.List[object]]::new()
            $uri = "https://graph.microsoft.com/$Version/$Resource$Extra"
            
            # Determine request type
            $Type = if ($Body) { 'Body' } 
                    elseif ($OutputFilePath) { 'Outfile' } 
                    else { 'Default' }

            Write-Verbose "Processing Microsoft Graph Response: $Method $uri"
            
            # Initial request
            $GraphReturn = switch ($Type) {
                'Body'    { Invoke-MgGraphRequest -Method $Method -Uri $uri -Body $Body }
                'Outfile' { Invoke-MgGraphRequest -Method $Method -Uri $uri -OutputFilePath "$OutputFilePath.zip" }
                Default   { Invoke-MgGraphRequest -Method $Method -Uri $uri }
            }
            
            # Handle OutFile scenario
            if ($Type -eq 'Outfile') {
                Write-Verbose "Data exported to $OutputFilePath.zip"
                return @{ Status = "Success"; FilePath = "$OutputFilePath.zip" }
            }
            
            # Collect initial results
            if ($GraphReturn.value) {
                $GrRaw.AddRange([array]$GraphReturn.value)
            } else {
                $GrRaw.Add($GraphReturn)
            }
            
            # Handle pagination (only for GET requests)
            $OutputNextLink = $GraphReturn."@odata.nextLink"
            if ($OutputNextLink -and $Method -ne 'Get') {
                Write-Warning "Pagination detected but Method is '$Method'. Only GET requests should be paginated."
            }
            
            $PageCount = 1
            $FixedPercent = 0
            
            while ($OutputNextLink) {
                $PageCount++
                $GraphReturn = Invoke-MgGraphRequest -Method Get -Uri $OutputNextLink
                $OutputNextLink = $GraphReturn."@odata.nextLink"
                
                # Update progress
                $FixedPercent = [Math]::Min(99, $FixedPercent + (100 - $FixedPercent) * 0.15)
                Write-Progress -Activity "Retrieving Graph Responses" `
                    -Status "Page $PageCount - $($GrRaw.Count) entries processed..." `
                    -PercentComplete $FixedPercent
                
                # Add results
                if ($GraphReturn.value) {
                    $GrRaw.AddRange([array]$GraphReturn.value)
                } else {
                    $GrRaw.Add($GraphReturn)
                }
            }
            
            Write-Progress -Activity "Retrieving Graph Call Responses" -Completed
        }
        catch {
            Write-Verbose "Microsoft Graph API call failed with error:"
            Write-Host "$(Show-ParseGraphError -ErrorString $_.ErrorDetails.Message)" -ForegroundColor Red
            throw
        }
    }
    
    end {
        Write-Verbose "Completed Microsoft Graph API call - Retrieved $($GrRaw.Count) items"
        return ($GrRaw.ToArray() | ConvertTo-Json | ConvertFrom-Json)
    }
}