# Public\Show-ParseGraphError.ps1

function Show-ParseGraphError {
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
        [string]$ErrorString
    )
    
    begin {
        $result = [ordered]@{
            Code = $null
            Message = $null
        }
    }
    
    process {
        # Extract Message (the nested one with actual error detail)
        if ($Err -match '"code":"(.*?)"\,"message') {
            $result.Code = $matches[1]
        } else {
            $result.Code = "Unknown error code"
        }

        if (($ErrorString -match '"message\\":\s*\\"(.*?)- Operation') -or ($ErrorString -match '"message":"(.*?)\s*https')) {
            $result.Message = $matches[1]
        } else {
            $result.Message = "No error message captured."
        }
    }
    
    end {
        return $result.Values
    }
}