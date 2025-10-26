# ParallelLoot Addon Deployment Script
# Copies the addon to your WoW AddOns directory
# Defaults to Classic (MoP Classic) since this addon is designed for MoP Classic

param(
    [string]$WowPath = "",
    [switch]$Retail,
    [switch]$Classic = $true,  # Default to Classic for MoP Classic
    [switch]$Help
)

function Show-Help {
    Write-Host @"
ParallelLoot Addon Deployment Script
=====================================
Designed for Mists of Pandaria Classic - defaults to Classic deployment

Usage:
  .\deploy-addon.ps1 [-WowPath <path>] [-Retail] [-Classic]

Parameters:
  -WowPath   Specify custom WoW installation path
  -Retail    Deploy to Retail (overrides default Classic)
  -Classic   Deploy to Classic Era or MoP Classic (DEFAULT)
  -Help      Show this help message

Examples:
  .\deploy-addon.ps1                                    # Deploys to Classic (default)
  .\deploy-addon.ps1 -Classic                          # Explicitly deploy to Classic
  .\deploy-addon.ps1 -Retail                           # Deploy to Retail instead
  .\deploy-addon.ps1 -WowPath "D:\Games\World of Warcraft"  # Custom path, Classic

Note: This addon is specifically designed for Mists of Pandaria Classic.
      Classic deployment is the default behavior.

"@
    exit 0
}

if ($Help) {
    Show-Help
}

# Determine WoW installation path
if (-not $WowPath) {
    # Common WoW installation paths
    $commonPaths = @(
        "C:\Program Files (x86)\World of Warcraft",
        "C:\Program Files\World of Warcraft",
        "$env:ProgramFiles\World of Warcraft",
        "${env:ProgramFiles(x86)}\World of Warcraft"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $WowPath = $path
            break
        }
    }
    
    if (-not $WowPath) {
        Write-Host "ERROR: Could not find WoW installation automatically." -ForegroundColor Red
        Write-Host "Please specify the path using -WowPath parameter" -ForegroundColor Yellow
        Write-Host "Example: .\deploy-addon.ps1 -WowPath 'C:\Games\World of Warcraft'" -ForegroundColor Yellow
        exit 1
    }
}

# Verify WoW path exists
if (-not (Test-Path $WowPath)) {
    Write-Host "ERROR: WoW path not found: $WowPath" -ForegroundColor Red
    exit 1
}

# Determine game version folder
# Override Classic flag if Retail is explicitly specified
if ($Retail) {
    $Classic = $false
    $versionFolders = @("_retail_")
    Write-Host "Deploying to Retail (overriding default Classic)" -ForegroundColor Yellow
} elseif ($Classic) {
    $versionFolders = @("_classic_", "_classic_era_")
    Write-Host "Deploying to Classic (MoP Classic)" -ForegroundColor Cyan
} else {
    # Fallback to Classic as default
    $Classic = $true
    $versionFolders = @("_classic_", "_classic_era_")
    Write-Host "Deploying to Classic (default for MoP Classic addon)" -ForegroundColor Cyan
}

$targetFolder = $null
foreach ($folder in $versionFolders) {
    $testPath = Join-Path $WowPath $folder
    if (Test-Path $testPath) {
        $targetFolder = $folder
        break
    }
}

if (-not $targetFolder) {
    Write-Host "ERROR: Could not find game version folder in $WowPath" -ForegroundColor Red
    Write-Host "Looking for: $($versionFolders -join ', ')" -ForegroundColor Yellow
    exit 1
}

# Build destination path
$addonsPath = Join-Path $WowPath "$targetFolder\Interface\AddOns\ParallelLoot"

Write-Host "Deploying ParallelLoot addon..." -ForegroundColor Cyan
Write-Host "Source: $PSScriptRoot\ParallelLoot" -ForegroundColor Gray
Write-Host "Destination: $addonsPath" -ForegroundColor Gray

# Create AddOns directory if it doesn't exist
$addonsDir = Split-Path $addonsPath -Parent
if (-not (Test-Path $addonsDir)) {
    New-Item -ItemType Directory -Path $addonsDir -Force | Out-Null
}

# Remove existing addon folder if it exists
if (Test-Path $addonsPath) {
    Write-Host "Removing existing addon..." -ForegroundColor Yellow
    Remove-Item -Path $addonsPath -Recurse -Force
}

# Copy addon files
try {
    Copy-Item -Path "$PSScriptRoot\ParallelLoot" -Destination $addonsPath -Recurse -Force
    Write-Host "SUCCESS: Addon deployed successfully!" -ForegroundColor Green
    Write-Host "Location: $addonsPath" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to copy addon files" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
