#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Generates Software Bill of Materials (SBOM) for all .NET projects using CycloneDX.

.DESCRIPTION
    This script discovers all .csproj files in the git repository and uses the CycloneDX
    tool to generate an SBOM in CycloneDX format for each project.

.PARAMETER OutputPath
    The output directory for the generated SBOM files. Defaults to './sbom'.

.PARAMETER OutputFormat
    The output format for the SBOM. Valid values: xml, json. Defaults to 'json'.

.PARAMETER ProjectFilter
    Optional filter pattern to match specific projects (e.g., "WebApi", "*.Tests").
    If not specified, generates SBOMs for all .csproj files.

.PARAMETER DependencyTrackUrl
    The URL of the Dependency Track instance. Defaults to 'http://localhost:8081'.

.PARAMETER DependencyTrackApiKey
    The API key for Dependency Track authentication. Required if uploading to Dependency Track.

.PARAMETER UploadToDependencyTrack
    Switch to enable uploading SBOMs to Dependency Track after generation.

.EXAMPLE
    .\generateSbom.ps1
    Generates SBOMs for all projects with default settings (json format in ./sbom directory)

.EXAMPLE
    .\generateSbom.ps1 -OutputPath "../artifacts/sbom" -OutputFormat xml
    Generates SBOMs in XML format in the specified directory

.EXAMPLE
    .\generateSbom.ps1 -ProjectFilter "WebApi"
    Generates SBOM only for projects matching "WebApi"

.EXAMPLE
    .\generateSbom.ps1 -UploadToDependencyTrack -DependencyTrackApiKey "your-api-key"
    Generates SBOMs and uploads them to the local Dependency Track instance

.EXAMPLE
    .\generateSbom.ps1 -UploadToDependencyTrack -DependencyTrackUrl "https://dtrack.company.com" -DependencyTrackApiKey "your-api-key"
    Generates SBOMs and uploads them to a custom Dependency Track instance
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./sbom",

    [Parameter(Mandatory = $false)]
    [ValidateSet("xml", "json")]
    [string]$OutputFormat = "json",

    [Parameter(Mandatory = $false)]
    [string]$ProjectFilter = "",

    [Parameter(Mandatory = $false)]
    [string]$DependencyTrackUrl = "http://localhost:8081",

    [Parameter(Mandatory = $false)]
    [string]$DependencyTrackApiKey = "odt_eTKGg7ZHYElASgSZDPESND7YqXcFj54c",

    [Parameter(Mandatory = $false)]
    [switch]$UploadToDependencyTrack
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get the script directory and navigate to the repository root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

# Validate Dependency Track parameters
if ($UploadToDependencyTrack -and [string]::IsNullOrWhiteSpace($DependencyTrackApiKey)) {
    Write-Error "DependencyTrackApiKey is required when UploadToDependencyTrack is specified"
    exit 1
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  CycloneDX SBOM Generation" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if ($UploadToDependencyTrack) {
    Write-Host "Upload to Dependency Track: Enabled" -ForegroundColor Green
    Write-Host "Dependency Track URL: $DependencyTrackUrl" -ForegroundColor Gray
    Write-Host ""
}

# Discover all .csproj files using git
Write-Host "Discovering .csproj files in repository..." -ForegroundColor Yellow
try {
    Push-Location $repoRoot

    # Use git ls-files to find all .csproj files in the repository
    $allProjects = git ls-files "*.csproj" 2>$null

    if ($LASTEXITCODE -ne 0 -or -not $allProjects) {
        Write-Warning "Git search failed or returned no results. Falling back to file system search..."
        $allProjects = Get-ChildItem -Path $repoRoot -Filter "*.csproj" -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\obj\\' -and $_.FullName -notmatch '\\bin\\' } |
        ForEach-Object { $_.FullName.Replace("$repoRoot\", "").Replace("\", "/") }
    }

    # Apply filter if specified
    if ($ProjectFilter) {
        $projects = $allProjects | Where-Object { $_ -like "*$ProjectFilter*" }
        if (-not $projects) {
            Write-Error "No projects found matching filter: $ProjectFilter"
            Pop-Location
            exit 1
        }
    }
    else {
        $projects = $allProjects
    }

    if (-not $projects) {
        Write-Error "No .csproj files found in the repository"
        Pop-Location
        exit 1
    }

    # Convert to array if single item
    if ($projects -is [string]) {
        $projects = @($projects)
    }

    Write-Host "✓ Found $($projects.Count) project(s):" -ForegroundColor Green
    foreach ($proj in $projects) {
        Write-Host "  • $proj" -ForegroundColor Gray
    }
    Write-Host ""
}
catch {
    Write-Error "Failed to discover projects: $_"
    Pop-Location
    exit 1
}

# Create output directory if it doesn't exist
$fullOutputPath = Join-Path $repoRoot $OutputPath
if (-not (Test-Path $fullOutputPath)) {
    Write-Host "Creating output directory: $fullOutputPath" -ForegroundColor Yellow
    New-Item -Path $fullOutputPath -ItemType Directory -Force | Out-Null
    Write-Host "✓ Output directory created" -ForegroundColor Green
    Write-Host ""
}

# Generate SBOM for each project
$successCount = 0
$failedProjects = @()
$uploadedProjects = @()
$uploadFailedProjects = @()
$outputFormatArg = if ($OutputFormat -eq "json") { "Json" } else { "Xml" }

Write-Host "Generating SBOMs..." -ForegroundColor Yellow
Write-Host ""

foreach ($project in $projects) {
    $projectPath = Join-Path $repoRoot $project
    $projectName = [System.IO.Path]::GetFileNameWithoutExtension($project)
    $projectOutputPath = Join-Path $fullOutputPath $projectName

    Write-Host "[$($successCount + $failedProjects.Count + 1)/$($projects.Count)] Processing: $projectName" -ForegroundColor Cyan
    Write-Host "  Project: $project" -ForegroundColor Gray
    Write-Host "  Output: $projectOutputPath" -ForegroundColor Gray

    # Create project-specific output directory
    if (-not (Test-Path $projectOutputPath)) {
        New-Item -Path $projectOutputPath -ItemType Directory -Force | Out-Null
    }

    try {
        # Run CycloneDX tool for this project
        dotnet tool exec CycloneDX $projectPath `
            -o $projectOutputPath `
            -F $outputFormatArg `
            2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "CycloneDX generation failed with exit code $LASTEXITCODE"
        }

        Write-Host "  ✓ SBOM generated successfully" -ForegroundColor Green
        $successCount++

        # Upload to Dependency Track if enabled
        if ($UploadToDependencyTrack) {
            Write-Host "  Uploading to Dependency Track..." -ForegroundColor Yellow

            # Find the generated BOM file
            $bomExtension = if ($OutputFormat -eq "json") { "json" } else { "xml" }
            $bomFile = Get-ChildItem -Path $projectOutputPath -Filter "bom.$bomExtension" | Select-Object -First 1

            if ($bomFile) {
                try {
                    # Read SBOM content and encode as base64
                    $bomContent = Get-Content -Path $bomFile.FullName -Raw
                    $bomBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($bomContent))

                    # Prepare request body
                    $body = @{
                        projectName    = $projectName
                        projectVersion = "1.0.0"
                        autoCreate     = $true
                        bom            = $bomBase64
                    } | ConvertTo-Json

                    # Upload to Dependency Track
                    $headers = @{
                        "X-Api-Key"    = $DependencyTrackApiKey
                        "Content-Type" = "application/json"
                    }

                    $response = Invoke-RestMethod -Uri "$DependencyTrackUrl/api/v1/bom" `
                        -Method Put `
                        -Headers $headers `
                        -Body $body `
                        -TimeoutSec 30

                    Write-Host "  ✓ Uploaded to Dependency Track (Token: $($response.token))" -ForegroundColor Green
                    $uploadedProjects += $projectName
                }
                catch {
                    Write-Host "  ✗ Upload failed: $_" -ForegroundColor Red
                    $uploadFailedProjects += $projectName
                }
            }
            else {
                Write-Host "  ✗ Upload failed: BOM file not found" -ForegroundColor Red
                $uploadFailedProjects += $projectName
            }
        }
    }
    catch {
        Write-Host "  ✗ Failed: $_" -ForegroundColor Red
        $failedProjects += $projectName
    }

    Write-Host ""
}

Pop-Location

# Summary
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Generation Summary" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Total projects: $($projects.Count)" -ForegroundColor White
Write-Host "SBOM Generation:" -ForegroundColor White
Write-Host "  Successful: $successCount" -ForegroundColor Green
Write-Host "  Failed: $($failedProjects.Count)" -ForegroundColor $(if ($failedProjects.Count -gt 0) { "Red" } else { "Green" })

if ($UploadToDependencyTrack) {
    Write-Host "Dependency Track Upload:" -ForegroundColor White
    Write-Host "  Successful: $($uploadedProjects.Count)" -ForegroundColor Green
    Write-Host "  Failed: $($uploadFailedProjects.Count)" -ForegroundColor $(if ($uploadFailedProjects.Count -gt 0) { "Red" } else { "Green" })
}

if ($failedProjects.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed projects (SBOM generation):" -ForegroundColor Red
    foreach ($failed in $failedProjects) {
        Write-Host "  • $failed" -ForegroundColor Gray
    }
}

if ($uploadFailedProjects.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed projects (Dependency Track upload):" -ForegroundColor Red
    foreach ($failed in $uploadFailedProjects) {
        Write-Host "  • $failed" -ForegroundColor Gray
    }
}

# List all generated SBOM files
if ($successCount -gt 0) {
    Write-Host ""
    Write-Host "Generated SBOM files:" -ForegroundColor Cyan
    $bomFiles = Get-ChildItem -Path $fullOutputPath -Filter "bom.*" -Recurse
    foreach ($file in $bomFiles) {
        $relativePath = $file.FullName.Replace("$fullOutputPath\", "")
        Write-Host "  • $relativePath ($('{0:N2}' -f ($file.Length / 1KB)) KB)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  SBOM Generation Complete" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
