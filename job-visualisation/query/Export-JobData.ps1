<#
.SYNOPSIS
    Connects to SQL Server via sqlcmd and exports job data to CSV files.

.PARAMETER ServerInstance
    SQL Server instance, e.g. "MYSERVER" or "MYSERVER\SQLEXPRESS".

.PARAMETER DaysBack
    Days of job history to export. Default: 30.

.PARAMETER OutputDir
    Directory to write CSV files. Default: ..\data relative to this script.

.PARAMETER UseWindowsAuth
    Use Windows authentication (default). Omit to be prompted for SQL credentials.

.EXAMPLE
    .\Export-JobData.ps1 -ServerInstance "MYSERVER" -DaysBack 7
    .\Export-JobData.ps1 -ServerInstance "MYSERVER\SQLEXPRESS" -DaysBack 30
#>
param(
    [Parameter(Mandatory)]
    [string]$ServerInstance,

    [int]$DaysBack = 30,

    [string]$OutputDir = (Join-Path $PSScriptRoot '..\data'),

    [switch]$UseWindowsAuth
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}
$OutputDir = Resolve-Path $OutputDir

# Column headers prepended to each CSV (sqlcmd runs with -h -1 to suppress its
# own header row, which would include an unwanted dashed separator line).
$headers = @{
    'jobs.csv'         = 'JobId,JobName,Category,Enabled,Description,Owner'
    'job_steps.csv'    = 'JobId,StepId,StepName,Subsystem,DatabaseName,OnSuccessAction,OnFailAction'
    'job_history.csv'  = 'InstanceId,JobId,JobName,StepId,StepName,RunStatus,RunStatusLabel,StartDateTime,DurationSeconds,DurationFormatted,JobRunInstanceId,Message,RetryCount,ServerName'
    'job_activity.csv' = 'JobId,JobName,RunRequestedDate,StartExecutionDate,StopExecutionDate,IsRunning,NextScheduledRun'
}

$sqlCredArgs = if ($UseWindowsAuth -or -not $PSBoundParameters.ContainsKey('UseWindowsAuth')) {
    @('-E')
} else {
    $cred = Get-Credential -Message "SQL Server credentials for $ServerInstance"
    @('-U', $cred.UserName, '-P', $cred.GetNetworkCredential().Password)
}

function Invoke-SqlExport {
    param(
        [string]$SqlFile,
        [string]$CsvFile,
        [hashtable]$SqlcmdVars = @{}
    )

    Write-Host "  Querying: $(Split-Path $SqlFile -Leaf) -> $CsvFile" -ForegroundColor Cyan

    $varArgs = $SqlcmdVars.GetEnumerator() |
               ForEach-Object { '-v'; "$($_.Key)=$($_.Value)" }

    # -s ','   column separator
    # -W       strip trailing spaces
    # -h -1    suppress header and separator rows
    # -f 65001 UTF-8 output
    $sqlcmdArgs = @(
        '-S', $ServerInstance
        '-i', $SqlFile
        '-s', ','
        '-W'
        '-h', '-1'
        '-f', '65001'
    ) + $sqlCredArgs + $varArgs

    $rows = & sqlcmd @sqlcmdArgs
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd exited with code $LASTEXITCODE for $SqlFile"
    }

    $fileName = Split-Path $CsvFile -Leaf
    @($headers[$fileName]) + $rows |
        Out-File -FilePath $CsvFile -Encoding UTF8 -Force

    $rowCount = ($rows | Measure-Object).Count
    Write-Host "    -> $rowCount rows written" -ForegroundColor DarkGray
}

Write-Host "`nExporting SQL Server job data from: $ServerInstance" -ForegroundColor Yellow
Write-Host "Output directory: $OutputDir`n"

Invoke-SqlExport -SqlFile "$PSScriptRoot\Get-Jobs.sql"        -CsvFile "$OutputDir\jobs.csv"
Invoke-SqlExport -SqlFile "$PSScriptRoot\Get-JobSteps.sql"    -CsvFile "$OutputDir\job_steps.csv"
Invoke-SqlExport -SqlFile "$PSScriptRoot\Get-JobHistory.sql"  -CsvFile "$OutputDir\job_history.csv" `
                 -SqlcmdVars @{ DaysBack = $DaysBack }
Invoke-SqlExport -SqlFile "$PSScriptRoot\Get-JobActivity.sql" -CsvFile "$OutputDir\job_activity.csv"

Write-Host "`nExport complete." -ForegroundColor Green
