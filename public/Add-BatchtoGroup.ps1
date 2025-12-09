# Public\Add-BatchtoGroup.ps1

function Add-BatchToGroup {
    <#
    .SYNOPSIS
        Adds multiple members to an Entra ID group using MS Graph batch requests
    
    .DESCRIPTION
        Efficiently adds users/objects to an Entra ID group using batched Graph API requests.
        Supports up to 20 members per batch request for optimal performance.
    
    .PARAMETER Members
        Array of objects containing an 'Id' property representing the member's directory object ID
    
    .PARAMETER EntGroupName
        Display name of the target Entra ID group
    
    .PARAMETER EntGroupID
        Object ID of the target Entra ID group
    
    .EXAMPLE
        Add-BatchToGroup -Members $users -EntGroupID "12345-abcde"
    
    .EXAMPLE
        $users | Add-BatchToGroup -EntGroupName "Developers"
    
    #>
    
    [CmdletBinding(DefaultParameterSetName = 'ById', SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [pscustomobject[]]$Members,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
        [ValidateNotNullOrEmpty()]
        [string]$EntGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [string]$EntGroupID
    )

    begin {
        Write-Verbose "Starting Add-BatchToGroup"
        
        ## Verify MS Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to MS Graph. Please run Connect-MgGraph."
        }

        ## Resolve Group ID if Name was provided
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            Write-Verbose "Resolving Group Name: $EntGroupName"
            try {
                $filter = "displayName eq '$($EntGroupName.Replace("'", "''"))'"  # Escape single quotes
                $uri = "https://graph.microsoft.com/v1.0/groups?`$filter=$filter&`$select=id"
                $groupResult = Invoke-MgGraphRequest -Method GET -Uri $uri
                
                if (-not $groupResult.value -or $groupResult.value.Count -eq 0) {
                    throw "Group '$EntGroupName' not found."
                }
                if ($groupResult.value.Count -gt 1) {
                    Write-Warning "Multiple groups found with name '$EntGroupName'. Using first match."
                }
                $EntGroupID = $groupResult.value[0].id
                Write-Verbose "Resolved Group ID: $EntGroupID"
            }
            catch {
                throw "Failed to resolve group: $_"
            }
        }

        ## Initialize collection for pipeline input
        $allMembers = [System.Collections.Generic.List[Object]]::new()
        
        ## Batch configuration
        $script:batchSize = 20
        $script:successCount = 0
        $script:failureCount = 0
        $script:failedMembers = [System.Collections.Generic.List[Object]]::new()
    }
    
    process {
        ## Collect all pipeline input
        foreach ($member in $Members) {
            if (-not $member.Id) {
                Write-Warning "Member object missing 'Id' property. Skipping."
                continue
            }
            $allMembers.Add($member)
        }
    }
    
    end {
        if ($allMembers.Count -eq 0) {
            Write-Warning "No valid members to add."
            return
        }

        Write-Verbose "Processing $($allMembers.Count) member(s)"
        
        ## Process in batches
        $batchNumber = 1
        for ($i = 0; $i -lt $allMembers.Count; $i += $script:batchSize) {
            $batchEnd = [Math]::Min($i + $script:batchSize, $allMembers.Count)
            $currentBatch = $allMembers[$i..($batchEnd - 1)]
            
            ## Build batch requests
            $requests = @()
            $requestId = 1
            
            foreach ($member in $currentBatch) {
                $requests += @{
                    id      = "$requestId"
                    method  = "POST"
                    url     = "/groups/$EntGroupID/members/`$ref"
                    body    = @{
                        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($member.Id)"
                    }
                    headers = @{
                        "Content-Type" = "application/json"
                    }
                }
                $requestId++
            }

            ## Execute batch request
            if ($PSCmdlet.ShouldProcess("Group $EntGroupID", "Add $($requests.Count) members (Batch $batchNumber)")) {
                try {
                    $batchBody = @{ requests = $requests }
                    $result = Invoke-MgGraphRequest -Method POST `
                        -Uri "https://graph.microsoft.com/v1.0/`$batch" `
                        -Body ($batchBody | ConvertTo-Json -Depth 10)

                    ## Process results
                    foreach ($response in $result.responses) {
                        if ($response.status -eq 204 -or $response.status -eq 201) {
                            $script:successCount++
                        }
                        else {
                            $script:failureCount++
                            $memberId = $currentBatch[$response.id - 1].Id
                            $errorMsg = $response.body.error.message
                            $script:failedMembers.Add([PSCustomObject]@{
                                MemberId = $memberId
                                Status   = $response.status
                                Error    = $errorMsg
                            })
                            Write-Warning "Failed to add member $memberId : $errorMsg"
                        }
                    }

                    Write-Host "Processed batch $batchNumber of $([Math]::Ceiling($allMembers.Count / $script:batchSize))" -ForegroundColor Cyan
                    $batchNumber++
                }
                catch {
                    Write-Error "Batch request failed: $_"
                    $script:failureCount += $requests.Count
                }
            }
        }

        ## Summary
        Write-Host "`nSummary:" -ForegroundColor Green
        Write-Host "  Successfully added: $script:successCount" -ForegroundColor Green
        if ($script:failureCount -gt 0) {
            Write-Host "  Failed: $script:failureCount" -ForegroundColor Red
            Write-Host "`nFailed members available in `$script:failedMembers" -ForegroundColor Yellow
        }
        
        Write-Verbose "Completed Add-BatchToGroup"
    }
}