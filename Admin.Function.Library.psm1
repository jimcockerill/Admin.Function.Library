# Admin.Function.Library.psm1

# Get the path to the module
$ModulePath = $PSScriptRoot

# Dot-source all Public functions
$PublicFunctions = Get-ChildItem -Path "$ModulePath\Public\*.ps1" -ErrorAction SilentlyContinue

foreach ($Function in $PublicFunctions) {
    try {
        . $Function.FullName
    }
    catch {
        Write-Error "Failed to import function $($Function.FullName): $_"
    }
}

# Dot-source all Private functions
$PrivateFunctions = Get-ChildItem -Path "$ModulePath\Private\*.ps1" -ErrorAction SilentlyContinue

foreach ($Function in $PrivateFunctions) {
    try {
        . $Function.FullName
    }
    catch {
        Write-Error "Failed to import function $($Function.FullName): $_"
    }
}

# Export only Public functions
Export-ModuleMember -Function $PublicFunctions.BaseName