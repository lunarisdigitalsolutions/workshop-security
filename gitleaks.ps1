#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Run Gitleaks security scanner in Docker
.DESCRIPTION
    Executes Gitleaks in a Docker container to scan for secrets and sensitive information
.PARAMETER Command
    The Gitleaks command to run (default: dir)
.PARAMETER Options
    Additional options to pass to Gitleaks
.EXAMPLE
    .\gitleaks.ps1
    .\gitleaks.ps1 -Command dir -Options "--verbose"
#>

param(
    [string]$Command = "dir",
    [string]$Options = ""
)

$scanPath = $PSScriptRoot

Write-Host "Running Gitleaks in Docker..." -ForegroundColor Cyan
Write-Host "Scan directory: $scanPath" -ForegroundColor Yellow

$dockerArgs = @(
    "run"
    "--rm"
    "-v"
    "${scanPath}:/repo"
    "ghcr.io/gitleaks/gitleaks:latest"
    $Command
)

if ($Options) {
    $dockerArgs += $Options.Split(" ")
}

$dockerArgs += "/repo"

$commandString = "docker " + ($dockerArgs -join " ")
Write-Host "Executing command: $commandString" -ForegroundColor Gray

& docker $dockerArgs
