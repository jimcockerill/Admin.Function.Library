# Public\Show-ArrayCompare.ps1
function Show-ArrayCompare {
    <#
    .SYNOPSIS
        Compares two arrays and returns matching or missing items based on a property.
    
    .DESCRIPTION
        Uses a HashSet for efficient lookup to find items in Dataset that match or are missing from Subset,
        based on a specified property value.
    
    .PARAMETER Dataset
        The main array of objects to filter
    
    .PARAMETER Subset
        Array of property values to compare against
    
    .PARAMETER Property
        The property name in Dataset objects to compare with Subset values
    
    .PARAMETER Mode
        'Match' returns items where property value is in Subset
        'Missing' returns items where property value is NOT in Subset
    
    .EXAMPLE
        $users = @(
            [PSCustomObject]@{Name='Alice'; Id=1}
            [PSCustomObject]@{Name='Bob'; Id=2}
            [PSCustomObject]@{Name='Charlie'; Id=3}
        )
        $activeIds = @('1', '3')
        
        Show-ArrayCompare -Dataset $users -Subset $activeIds -Property 'Id' -Mode 'Match'
        # Returns Alice and Charlie
    
    .EXAMPLE
        Show-ArrayCompare -Dataset $users -Subset $activeIds -Property 'Id' -Mode 'Missing'
        # Returns Bob
    
    .NOTES
        Author: Optimized Version
        Date: 2024-12-01
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Dataset,

        [Parameter(Mandatory = $true)]
        [string[]]$Subset,
        
        [Parameter(Mandatory = $true)]
        [string]$Property,
        
        [ValidateSet("Match", "Missing")]
        [Parameter(Mandatory = $true)]
        [string]$Mode
    )
    
    begin {
        Write-Verbose "Starting Array Comparison: Mode=$Mode, Property=$Property"
    }
    
    process {
        # Create HashSet directly from array for better performance
        $HashSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$Subset)
        
        Write-Verbose "HashSet created with $($HashSet.Count) items"
        
        # Use switch for cleaner logic
        $Result = switch ($Mode) {
            'Match' {
                $Dataset.Where({ $HashSet.Contains([string]$_.$Property) })
            }
            'Missing' {
                $Dataset.Where({ -not $HashSet.Contains([string]$_.$Property) })
            }
        }
        
        Write-Verbose "Comparison complete: $($Result.Count) items found"
        return $Result
    }
    
    end {
        Write-Verbose "Completed Array Comparison"
    }
}