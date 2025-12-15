# Public\Compare-Arrays.ps1
function Compare-Arrays {
    <#
    .SYNOPSIS
        Compares two arrays and returns matching or missing items based on a property.
    
    .DESCRIPTION
        Uses a HashSet for efficient lookup to find items in Source that match or are missing from Compare,
        based on a specified property value.
    
    .PARAMETER Source
        The main array of objects to filter
    
    .PARAMETER Compare
        Array of property values to compare against
    
    .PARAMETER Property
        The property name in Source objects to compare with Compare values
    
    .PARAMETER Mode
        'Match' returns items where property value is in Compare
        'Missing' returns items where property value is NOT in Compare
    
    .EXAMPLE
        $users = @(
            [PSCustomObject]@{Name='Alice'; Id=1}
            [PSCustomObject]@{Name='Bob'; Id=2}
            [PSCustomObject]@{Name='Charlie'; Id=3}
        )
        $activeIds = @('1', '3')
        
        Compare-Arrays-Source $users -Compare $activeIds -Property 'Id' -Mode 'Match'
        # Returns Alice and Charlie
    
    .EXAMPLE
        Compare-Arrays-Source $users -Compare $activeIds -Property 'Id' -Mode 'Missing'
        # Returns Bob
    
    .NOTES
        Author: James Cockerill
        Date: 01/12/2025
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Source,

        [Parameter(Mandatory = $true)]
        [string[]]$Compare,
        
        [Parameter(Mandatory = $false)]
        [string]$Property,
        
        [ValidateSet("Match", "Missing")]
        [Parameter(Mandatory = $true)]
        [string]$Mode
    )
    
    begin {
        if ([bool]($Property)) {
            Write-Verbose "Starting Array Comparison: Mode=$Mode, Property=$Property"
        } else {
            Write-Verbose "Starting Array Comparison: Mode=$Mode"
        }
    }
    
    process {
        # Create HashSet directly from array for better performance
        $HashSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$Compare)
        
        Write-Verbose "HashSet created with $($HashSet.Count) items"
        
        # Use switch for cleaner logic
        $Result = switch ($Mode) {
            'Match' {
                if ([bool]($Property)) {
                    $Source.Where({ $HashSet.Contains([string]$_.$Property) })
                } else {
                    $Source.Where({ $HashSet.Contains([string]$_) })
                }
            }
            'Missing' {
                if ([bool]($Property)) {
                    $Source.Where({ -not $HashSet.Contains([string]$_.$Property) })
                } else {
                    $Source.Where({ -not $HashSet.Contains([string]$_) })
                }
            }
        }
        
        Write-Verbose "Comparison complete: $($Result.Count) items found"
        return $Result
    }
    
    end {
        Write-Verbose "Completed Array Comparison"
    }
}