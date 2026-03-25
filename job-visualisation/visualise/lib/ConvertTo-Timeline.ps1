function ConvertTo-Timeline {
    param(
        [object[]]$History,
        [object[]]$Activity,
        [object[]]$Jobs,
        [string]$Date,
        [datetime]$ReportTime,
        [int]$WindowStartHour = 0,
        [int]$WindowEndHour   = 24
    )

    $windowStart = $WindowStartHour * 60
    $windowEnd   = $WindowEndHour   * 60
    $windowSpan  = $windowEnd - $windowStart

    function ConvertTo-HtmlEncoded([string]$s) {
        if ([string]::IsNullOrEmpty($s)) { return '' }
        $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;').Replace("'",'&#39;')
    }

    function Get-MinutesFromMidnight([string]$isoDateTime) {
        $dt = [datetime]::Parse($isoDateTime)
        return $dt.Hour * 60 + $dt.Minute + $dt.Second / 60.0
    }

    function Get-BarStyle([double]$startMin, [double]$durationMin) {
        $endMin       = $startMin + $durationMin
        $clampedStart = [math]::Max($startMin, $windowStart)
        $clampedEnd   = [math]::Min($endMin,   $windowEnd)
        if ($clampedEnd -le $clampedStart) { return $null }
        $left  = [math]::Round(($clampedStart - $windowStart) / $windowSpan * 100, 4)
        $width = [math]::Round(($clampedEnd   - $clampedStart) / $windowSpan * 100, 4)
        return "left:${left}%;width:${width}%;"
    }

    function Get-StatusClass([string]$label) {
        switch ($label.ToLower().Trim()) {
            'succeeded'  { return 'status-succeeded'  }
            'failed'     { return 'status-failed'     }
            'retry'      { return 'status-retry'      }
            'cancelled'  { return 'status-cancelled'  }
            'inprogress' { return 'status-inprogress' }
            default      { return 'status-unknown'    }
        }
    }

    # ── Collect run objects from history and activity ─────────────────────────
    $runs = [System.Collections.Generic.List[PSObject]]::new()

    # Completed / historical runs (job-level rows only)
    $History | Where-Object { $_.StepId -eq '0' -and $_.StartDateTime.StartsWith($Date) } |
    ForEach-Object {
        $startMin = Get-MinutesFromMidnight $_.StartDateTime
        $durMin   = [int]$_.DurationSeconds / 60.0
        $start    = $_.StartDateTime.Substring(11, 5)
        $runs.Add([PSCustomObject]@{
            JobId       = $_.JobId
            JobName     = $_.JobName
            StartMin    = $startMin
            DurationMin = $durMin
            StatusLabel = $_.RunStatusLabel
            InstanceId  = $_.InstanceId
            Tooltip     = "$($_.JobName) | $start | $($_.DurationFormatted) | $($_.RunStatusLabel)"
        })
    }

    # Currently running jobs from activity
    $Activity | Where-Object { $_.IsRunning -eq 'TRUE' -and $_.StartExecutionDate.StartsWith($Date) } |
    ForEach-Object {
        $startDt    = [datetime]::Parse($_.StartExecutionDate)
        $startMin   = $startDt.Hour * 60 + $startDt.Minute + $startDt.Second / 60.0
        $durMin     = ($ReportTime - $startDt).TotalMinutes
        if ($durMin -lt 0) { $durMin = 0 }
        $elapsedSec = [int](($ReportTime - $startDt).TotalSeconds)
        $elapsed    = '{0}:{1:D2}:{2:D2}' -f [int]($elapsedSec/3600), [int](($elapsedSec%3600)/60), ($elapsedSec%60)
        $runs.Add([PSCustomObject]@{
            JobId       = $_.JobId
            JobName     = $_.JobName
            StartMin    = $startMin
            DurationMin = $durMin
            StatusLabel = 'InProgress'
            InstanceId  = ''
            Tooltip     = "$($_.JobName) | $($_.StartExecutionDate.Substring(11,5)) | Elapsed: $elapsed | Running"
        })
    }

    if ($runs.Count -eq 0) {
        return @"
<div class="card"><div class="card-body">
  <div class="alert alert-info mb-0">No job runs found for $Date in the selected time window.</div>
</div></div>
"@
    }

    # ── Axis labels ───────────────────────────────────────────────────────────
    $axisHtml  = [System.Text.StringBuilder]::new()
    [void]$axisHtml.Append('<div class="tl-axis">')
    $stepHours = if (($WindowEndHour - $WindowStartHour) -le 12) { 1 } else { 2 }
    for ($h = $WindowStartHour; $h -le $WindowEndHour; $h += $stepHours) {
        [void]$axisHtml.Append("<div class=`"tl-axis-label`">$('{0:D2}:00' -f $h)</div>")
    }
    [void]$axisHtml.Append('</div>')

    # ── Alternating-hour shading ──────────────────────────────────────────────
    $shadingHtml = [System.Text.StringBuilder]::new()
    for ($h = $WindowStartHour; $h -lt $WindowEndHour; $h++) {
        if ($h % 2 -eq 1) {
            $left  = [math]::Round(($h * 60 - $windowStart) / $windowSpan * 100, 4)
            $width = [math]::Round(60.0 / $windowSpan * 100, 4)
            [void]$shadingHtml.Append(
                "<div class=`"tl-track-bg`" style=`"left:${left}%;width:${width}%`"></div>")
        }
    }
    $shading = $shadingHtml.ToString()

    # ── One row per job, sorted by earliest run time ──────────────────────────
    $byJob    = $runs | Group-Object -Property JobName |
                Sort-Object { ($_.Group | Measure-Object StartMin -Minimum).Minimum }
    $rowsHtml = [System.Text.StringBuilder]::new()

    foreach ($group in $byJob) {
        $jobId    = $group.Group[0].JobId
        $safeName = ConvertTo-HtmlEncoded $group.Name
        $barsHtml = [System.Text.StringBuilder]::new()

        foreach ($run in ($group.Group | Sort-Object StartMin)) {
            $sc    = Get-StatusClass $run.StatusLabel
            $style = Get-BarStyle $run.StartMin $run.DurationMin
            if ($null -eq $style) { continue }
            $tip   = ConvertTo-HtmlEncoded $run.Tooltip
            $click = if ($run.InstanceId) { "navigateToJob('$($run.JobId)')" } else { '' }
            [void]$barsHtml.Append(
                "<div class=`"tl-bar $sc`" style=`"$style`" title=`"$tip`" onclick=`"$click`"></div>")
        }

        [void]$rowsHtml.Append(@"
<div class="tl-row">
  <div class="tl-label" title="$safeName" onclick="navigateToJob('$jobId')" style="cursor:pointer">$safeName</div>
  <div class="tl-track">$shading$($barsHtml.ToString())</div>
</div>
"@)
    }

    # ── Legend ────────────────────────────────────────────────────────────────
    $legend = @"
<span class="badge status-succeeded me-1">Succeeded</span>
<span class="badge status-failed me-1">Failed</span>
<span class="badge status-retry me-1" style="color:#000">Retry</span>
<span class="badge status-cancelled me-1">Cancelled</span>
<span class="badge status-inprogress me-1">Running</span>
"@

    return @"
<div class="card">
  <div class="card-header d-flex flex-wrap align-items-center gap-2 py-2">
    <strong>Timeline &mdash; $Date</strong>
    <div class="d-flex flex-wrap gap-1 ms-2">$legend</div>
    <span class="ms-auto text-muted small">Click a bar or job name to jump to history</span>
  </div>
  <div class="card-body p-2 timeline-wrap">
    <div class="timeline-grid">
      $($axisHtml.ToString())
      $($rowsHtml.ToString())
    </div>
  </div>
</div>
"@
}
