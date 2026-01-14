# Public\Send-FileToBlob.ps1

function Send-FileToBlob {
<#
    .SYNOPSIS
        Uploads a file to Azure Blob Storage using REST API with Shared Key authentication
    
    .DESCRIPTION
        Uploads a local file to an Azure Storage blob container using the REST API.
        Requires storage account name, access key, and target container/blob details.
    
    .PARAMETER StorageAccountName
        Name of the Azure Storage account
    
    .PARAMETER StorageAccountKey
        Access key for the storage account (base64 encoded)
    
    .PARAMETER ContainerName
        Name of the blob container
    
    .PARAMETER BlobName
        Name for the blob (including path if needed, e.g., "folder/file.txt")
    
    .PARAMETER FilePath
        Local path to the file to upload
    
    .EXAMPLE
        Send-FileToBlob -StorageAccountName "mystorageacct" -StorageAccountKey "key..." -ContainerName "logs" -BlobName "app.log" -FilePath "C:\temp\app.log"
    
    .NOTES
        Author: James Cockerill
        Date: 2026-01-08
    #>
    
[CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$StorageAccountName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$StorageAccountKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ContainerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BlobName,

        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath
    )
    
    begin {
        #Validate file exists and is readable
        if (-not (Test-Path $FilePath -PathType Leaf)) {
            throw "File not found: $FilePath"
        }

        #Read file
        try {
            $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
            $fileLength = $fileBytes.Length
        }
        catch {
            throw "Failed to read file: $_"
        }
        
        #Build URI
        $uri = "https://$StorageAccountName.blob.core.windows.net/$ContainerName/$BlobName"
        
        #Create date header (RFC1123 format)
        $date = [DateTime]::UtcNow.ToString("R")
        
        #Build canonical headers and resource (order matters for signature)
        $canonicalHeaders = "x-ms-blob-type:BlockBlob`nx-ms-date:$date`nx-ms-version:2021-06-08"
        $canonicalResource = "/$StorageAccountName/$ContainerName/$BlobName"
        
        #Build signature string (proper format for SharedKey)
        $stringToSign = "PUT`n`n`n$fileLength`n`napplication/octet-stream`n`n`n`n`n`n`n$canonicalHeaders`n$canonicalResource"
        
        #Create HMAC SHA256 signature
        try {
            $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
            $hmacsha.Key = [Convert]::FromBase64String($StorageAccountKey)
            $signature = [Convert]::ToBase64String($hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))
        }
        catch {
            throw "Failed to create signature: $_"
        }
        finally {
            if ($hmacsha) { $hmacsha.Dispose() }
        }
        
        # Build headers
        $headers = @{
            "x-ms-date"      = $date
            "x-ms-version"   = "2021-06-08"
            "x-ms-blob-type" = "BlockBlob"
            "Authorization"  = "SharedKey $($StorageAccountName):$signature"
            "Content-Length" = $fileLength
        }
    }
    
    process {
        try {
            $response = Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $fileBytes -ContentType "application/octet-stream"
            Write-Log "File uploaded successfully" -ForegroundColor Green
            $response = $true
        }
        catch {
            Write-Error "Upload failed: $_"
            $response = $false
        }

    }
    
    end {
        return $response
    }
}