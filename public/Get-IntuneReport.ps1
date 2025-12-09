# Public\Get-IntuneReport.ps1

function Get-IntuneReport {
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
        [string]$Body,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDir
    )
    
    begin {
        Write-Verbose "Generating Intune Report request"
        
        ## Verify MS Graph connection
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to MS Graph. Please run Connect-MgGraph."
        }
    }
    
    process {
        $RequestReply = $null
        $ExportJobData = $null
        #Prepare Local Cache folder and download report
        if (Test-path "$WorkingDir\TMP") {
            Get-ChildItem -Path "$WorkingDir\TMP\*.csv" |  Remove-Item -Force
            Get-ChildItem -Path "$WorkingDir\TMP\*.zip" |  Remove-Item -Force
        } else {
            New-Item -Path "$WorkingDir\TMP" -ItemType 'Directory'
        }

        ##Request Report via Graph API
        $Resource = 'deviceManagement/reports/exportJobs'
        $RepName = $(($Body | ConvertFrom-Json).reportName)
        $Report = "$RepName-$(Get-Date -Format "yyyyMMddHHmmss")"
        $RequestReply = Get-MgGraphTask -Method 'Post' -Version 'beta' -Resource $Resource -Body $Body
        while ($true) {
            $ExportJobData = Get-MgGraphTask -Method 'Get' -Version 'beta' -Resource "deviceManagement/reports/exportJobs('$($RequestReply.id)')"
            $FixedPercent = [Math]::Min(99, $FixedPercent + (100 - $FixedPercent) * 0.15)
            Write-Progress -Activity "Processing Report..." -PercentComplete $FixedPercent
            if ($ExportJobData.status -eq 'completed') {
                Invoke-WebRequest -Uri $ExportJobData.url -OutFile "$WorkingDir\TMP\$Report.zip"
                break
            }
            Start-Sleep -Seconds 1
        }

        ##Import downloaded report
        Expand-Archive -Path "$WorkingDir\TMP\$Report.zip" -DestinationPath "$WorkingDir\TMP"
        do {
            Start-Sleep 1
        } until (
            (Get-ChildItem "$WorkingDir\TMP\*.csv").Name.count -gt 0
        )
        $ReturnedData = Import-Csv -Path "$WorkingDir\TMP\$RepName*.csv" -Encoding 'UTF8' # Import the CSV data.

        ##Clean up local files/folders
        Remove-Item -Path "$WorkingDir\TMP\$Report.zip" -Force -EA Ignore
        Get-ChildItem -Path "$WorkingDir\TMP\$RepName*.csv" | Remove-Item -Force
    }
    
    end {
        Write-Verbose "Report Created and Presented"
        Return $ReturnedData
    }
}