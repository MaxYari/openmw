if (-Not (Test-Path CMakeCache.txt))
{
    Write-Error "This script must be run from the build directory."
}

if (-Not (Test-Path .cmake\api\v1\reply\index-*.json) -Or -Not ((Get-Content -Raw .cmake\api\v1\reply\index-*.json | ConvertFrom-Json).reply.PSObject.Properties.Name -contains "codemodel-v2"))
{
    Write-Output "Running CMake query..."
    New-Item -Type File -Force .cmake\api\v1\query\codemodel-v2
    cmake .
    Write-Output "Done."
}

try
{
    Push-Location .cmake\api\v1\reply

    $index = Get-Content -Raw index-*.json | ConvertFrom-Json

    $codemodel = Get-Content -Raw $index.reply."codemodel-v2".jsonFile | ConvertFrom-Json

    $targets = @()
    $codemodel.configurations | ForEach-Object {
        $_.targets | ForEach-Object {
            $target = Get-Content -Raw $_.jsonFile | ConvertFrom-Json
            if ($target.type -eq "EXECUTABLE" -or $target.type -eq "SHARED_LIBRARY")
            {
                $targets += $target
            }
        }
    }

    $artifacts = @()
    $targets | ForEach-Object {
        $_.artifacts | ForEach-Object {
            $artifacts += $_.path
        }
    }
}
finally
{
    Pop-Location
}

if (-not (Test-Path symstore-venv))
{
    python -m venv symstore-venv
}
$symstoreVersion = "0.3.4"
if (-not (Test-Path symstore-venv\Scripts\symstore.exe) -or -not ((symstore-venv\Scripts\pip show symstore | Select-String '(?<=Version: ).*').Matches.Value -eq $symstoreVersion))
{
    symstore-venv\Scripts\pip install symstore==$symstoreVersion
}
$artifacts = $artifacts | Where-Object { Test-Path $_ }
Write-Output "Storing symbols..."
symstore-venv\Scripts\symstore --compress --skip-published .\SymStore @artifacts
Write-Output "Done."
