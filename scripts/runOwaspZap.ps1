#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Runs OWASP ZAP security scanning against a target URL using Docker.

.DESCRIPTION
    This script pulls the OWASP ZAP Docker image and runs a security scan
    against the specified target URL. It generates a report in the specified format.

.PARAMETER TargetUrl
    The target URL to scan. Defaults to 'http://localhost:4200'.

.PARAMETER ScanType
    The type of scan to perform. Valid values: baseline, full. Defaults to 'baseline'.
    - baseline: Quick scan for common vulnerabilities
    - full: Comprehensive active scan (takes longer)

.PARAMETER OutputPath
    The output directory for the scan report. Defaults to './zap-reports'.

.PARAMETER ReportFormat
    The report format. Valid values: html, xml, json, md. Defaults to 'html'.

.PARAMETER PullLatest
    Switch to force pulling the latest ZAP image.

.EXAMPLE
    .\runOwaspZap.ps1
    Runs a baseline scan against http://localhost:4200 with default settings

.EXAMPLE
    .\runOwaspZap.ps1 -TargetUrl "http://localhost:5000"
    Runs a baseline scan against a custom URL

.EXAMPLE
    .\runOwaspZap.ps1 -ScanType full -ReportFormat json
    Runs a full active scan and generates a JSON report

.EXAMPLE
    .\runOwaspZap.ps1 -TargetUrl "http://localhost:4200" -PullLatest
    Pulls the latest ZAP image before scanning
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$TargetUrl = "http://localhost:4200",

    [Parameter(Mandatory = $false)]
    [ValidateSet("baseline", "full")]
    [string]$ScanType = "baseline",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "./zap-reports",

    [Parameter(Mandatory = $false)]
    [ValidateSet("html", "xml", "json", "md")]
    [string]$ReportFormat = "html",

    [Parameter(Mandatory = $false)]
    [switch]$PullLatest
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get the script directory and navigate to the repository root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  OWASP ZAP Security Scanner" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is available
Write-Host "Checking Docker availability..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed"
    }
    Write-Host "✓ Docker is available: $dockerVersion" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "Docker is not available. Please install Docker Desktop and ensure it's running."
    exit 1
}

# Pull ZAP Docker image
if ($PullLatest) {
    Write-Host "Pulling latest OWASP ZAP Docker image..." -ForegroundColor Yellow
    try {
        docker pull zaproxy/zap-stable
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to pull ZAP Docker image"
        }
        Write-Host "✓ ZAP Docker image pulled successfully" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Error "Failed to pull ZAP Docker image: $_"
        exit 1
    }
}
else {
    Write-Host "Checking for OWASP ZAP Docker image..." -ForegroundColor Yellow
    $imageExists = docker images zaproxy/zap-stable --format "{{.Repository}}" 2>$null
    if (-not $imageExists) {
        Write-Host "Image not found locally. Pulling..." -ForegroundColor Yellow
        try {
            docker pull zaproxy/zap-stable
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to pull ZAP Docker image"
            }
            Write-Host "✓ ZAP Docker image pulled successfully" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to pull ZAP Docker image: $_"
            exit 1
        }
    }
    else {
        Write-Host "✓ ZAP Docker image found locally" -ForegroundColor Green
    }
    Write-Host ""
}

# Create output directory
$fullOutputPath = Join-Path $repoRoot $OutputPath
if (-not (Test-Path $fullOutputPath)) {
    Write-Host "Creating output directory: $fullOutputPath" -ForegroundColor Yellow
    New-Item -Path $fullOutputPath -ItemType Directory -Force | Out-Null
    Write-Host "✓ Output directory created" -ForegroundColor Green
    Write-Host ""
}

# Generate report filename with timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportFileName = "zap-report-$timestamp.$ReportFormat"
$reportPath = Join-Path $fullOutputPath $reportFileName

# Determine scan script based on scan type
$zapScript = if ($ScanType -eq "baseline") {
    "zap-baseline.py"
}
else {
    "zap-full-scan.py"
}

# Prepare Docker command
Write-Host "Starting OWASP ZAP scan..." -ForegroundColor Yellow
Write-Host "  Target URL: $TargetUrl" -ForegroundColor Gray
Write-Host "  Scan Type: $ScanType" -ForegroundColor Gray
Write-Host "  Report Format: $ReportFormat" -ForegroundColor Gray
Write-Host "  Report Path: $reportPath" -ForegroundColor Gray
Write-Host ""
Write-Host "This may take several minutes depending on the scan type..." -ForegroundColor Yellow
Write-Host ""

try {
    # Replace localhost with host.docker.internal for container access to host
    $containerTargetUrl = $TargetUrl -replace 'localhost', 'host.docker.internal'

    # Run ZAP scan
    # Note: -t for target, -r for report file, -I to ignore warnings
    # -u zap ensures the container runs as the zap user to avoid permission issues
    docker run --rm `
        -v "$($fullOutputPath):/zap/wrk:rw" `
        -u zap `
        zaproxy/zap-stable `
        $zapScript `
        -t $containerTargetUrl `
        -r $reportFileName `
        -I

    if ($LASTEXITCODE -ne 0) {
        throw "ZAP scan failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "✓ ZAP scan completed successfully!" -ForegroundColor Green
    Write-Host ""

    # Check if report was generated
    if (Test-Path $reportPath) {
        $reportSize = (Get-Item $reportPath).Length
        Write-Host "Report generated:" -ForegroundColor Cyan
        Write-Host "  File: $reportFileName" -ForegroundColor White
        Write-Host "  Size: $('{0:N2}' -f ($reportSize / 1KB)) KB" -ForegroundColor White
        Write-Host "  Path: $reportPath" -ForegroundColor White
        Write-Host ""
        Write-Host "Opening report..." -ForegroundColor Yellow
        Start-Process $reportPath
    }
    else {
        Write-Warning "Report file was not found at expected location: $reportPath"
    }
}
catch {
    Write-Error "Failed to run ZAP scan: $_"
    exit 1
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  ZAP Scan Complete" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review the generated report: $reportPath" -ForegroundColor Gray
Write-Host "  2. Address any identified vulnerabilities" -ForegroundColor Gray
Write-Host "  3. Re-run the scan to verify fixes" -ForegroundColor Gray
Write-Host ""
