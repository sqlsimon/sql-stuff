<#
.SYNOPSIS
    Reads job data CSVs and generates an HTML job monitoring report.

.PARAMETER DataDir
    Directory containing the CSV files from Export-JobData.ps1.
    Default: ..\data relative to this script.

.PARAMETER OutputDir
    Directory to write the HTML report.
    Default: ..\output relative to this script.

.PARAMETER ReportDate
    Date label used in the report title and output filename (yyyy-MM-dd).
    Default: today.

.PARAMETER TimelineDate
    Date to display on the timeline (yyyy-MM-dd).
    Default: today.

.PARAMETER WindowStartHour
    Start hour for the timeline window (0-23). Default: 0.

.PARAMETER WindowEndHour
    End hour for the timeline window (1-24). Default: 24.

.PARAMETER Open
    Switch. Opens the generated report in the default browser.

.EXAMPLE
    .\New-JobReport.ps1
    .\New-JobReport.ps1 -TimelineDate 2026-03-25 -WindowStartHour 0 -WindowEndHour 12 -Open
#>
param(
    [string]$DataDir      = (Join-Path $PSScriptRoot '..\data'),
    [string]$OutputDir    = (Join-Path $PSScriptRoot '..\output'),
    [string]$ReportDate   = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$TimelineDate = (Get-Date -Format 'yyyy-MM-dd'),

    [ValidateRange(0,23)]
    [int]$WindowStartHour = 0,

    [ValidateRange(1,24)]
    [int]$WindowEndHour = 24,

    [switch]$Open
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\lib\Get-HtmlTemplate.ps1"
. "$PSScriptRoot\lib\ConvertTo-Timeline.ps1"
. "$PSScriptRoot\lib\ConvertTo-HistoryTable.ps1"

# ── Load CSVs ─────────────────────────────────────────────────────────────────
Write-Host "Loading data from: $DataDir" -ForegroundColor Cyan
$jobs     = Import-Csv (Join-Path $DataDir 'jobs.csv')
$steps    = Import-Csv (Join-Path $DataDir 'job_steps.csv')
$history  = Import-Csv (Join-Path $DataDir 'job_history.csv')
$activity = Import-Csv (Join-Path $DataDir 'job_activity.csv')
Write-Host "  Jobs: $($jobs.Count)  Steps: $($steps.Count)  History rows: $($history.Count)  Activity: $($activity.Count)"

# ── Build sections ────────────────────────────────────────────────────────────
$reportTime = Get-Date
Write-Host "Building timeline ($TimelineDate, $( '{0:D2}:00' -f $WindowStartHour )-$( '{0:D2}:00' -f $WindowEndHour ))..." -ForegroundColor Cyan

$timelineHtml = ConvertTo-Timeline `
    -History         $history `
    -Activity        $activity `
    -Jobs            $jobs `
    -Date            $TimelineDate `
    -ReportTime      $reportTime `
    -WindowStartHour $WindowStartHour `
    -WindowEndHour   $WindowEndHour

Write-Host "Building history table..." -ForegroundColor Cyan
$historyHtml = ConvertTo-HistoryTable -History $history -Jobs $jobs -Steps $steps

# ── Assemble and write ────────────────────────────────────────────────────────
$fullHtml = Get-HtmlTemplate `
    -Title           "SQL Server Job Monitor - $ReportDate" `
    -TimelineSection $timelineHtml `
    -HistorySection  $historyHtml `
    -GeneratedAt     ($reportTime.ToString('yyyy-MM-dd HH:mm:ss')) `
    -TimelineDate    $TimelineDate `
    -WindowStartHour $WindowStartHour `
    -WindowEndHour   $WindowEndHour

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
$outFile = Join-Path (Resolve-Path $OutputDir) "job-report-$ReportDate.html"
$fullHtml | Out-File -FilePath $outFile -Encoding UTF8 -Force

Write-Host "Report written to: $outFile" -ForegroundColor Green
if ($Open) { Start-Process $outFile }
