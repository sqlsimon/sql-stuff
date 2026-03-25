function ConvertTo-HistoryTable {
    param(
        [object[]]$History,
        [object[]]$Jobs,
        [object[]]$Steps
    )

    function ConvertTo-HtmlEncoded([string]$s) {
        if ([string]::IsNullOrEmpty($s)) { return '' }
        $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;').Replace("'",'&#39;')
    }

    function Get-BadgeClass([string]$status) {
        switch ($status.ToLower().Trim()) {
            'succeeded'  { return 'bs-succeeded'  }
            'failed'     { return 'bs-failed'     }
            'retry'      { return 'bs-retry'      }
            'cancelled'  { return 'bs-cancelled'  }
            'inprogress' { return 'bs-inprogress' }
            default      { return 'bs-unknown'    }
        }
    }

    # Max duration across all rows for proportional bar widths
    $maxDur = ($History | ForEach-Object { [int]$_.DurationSeconds } | Measure-Object -Maximum).Maximum
    if (-not $maxDur -or $maxDur -eq 0) { $maxDur = 1 }

    function Get-DurBar([int]$seconds) {
        $pct = [math]::Round($seconds / $maxDur * 100, 1)
        $h   = [int]($seconds / 3600)
        $m   = [int](($seconds % 3600) / 60)
        $s   = $seconds % 60
        $tip = if ($h -gt 0) { "${h}h ${m}m ${s}s" } elseif ($m -gt 0) { "${m}m ${s}s" } else { "${s}s" }
        return "<div class=`"dur-wrap`" title=`"$tip`"><div class=`"dur-fill`" style=`"width:${pct}%`"></div></div>"
    }

    # ── Index step rows by JobRunInstanceId ───────────────────────────────────
    $stepIndex = @{}
    $History | Where-Object { $_.StepId -ne '0' } | ForEach-Object {
        $key = $_.JobRunInstanceId
        if (-not $stepIndex.ContainsKey($key)) {
            $stepIndex[$key] = [System.Collections.Generic.List[object]]::new()
        }
        $stepIndex[$key].Add($_)
    }

    # ── Job-level runs, most recent first ─────────────────────────────────────
    $jobRuns = $History | Where-Object { $_.StepId -eq '0' } |
               Sort-Object -Property StartDateTime -Descending

    # Unique job IDs in order of most recent run
    $seenJobs      = [System.Collections.Generic.List[string]]::new()
    $orderedJobIds = [System.Collections.Generic.List[string]]::new()
    $jobRuns | ForEach-Object {
        if (-not $seenJobs.Contains($_.JobId)) {
            $seenJobs.Add($_.JobId)
            $orderedJobIds.Add($_.JobId)
        }
    }

    # ── Summary stats per job (shown in group header) ─────────────────────────
    $jobStats = @{}
    $jobRuns | Group-Object JobId | ForEach-Object {
        $runs      = @($_.Group)
        $succeeded = @($runs | Where-Object { $_.RunStatusLabel -eq 'Succeeded' }).Count
        $failed    = @($runs | Where-Object { $_.RunStatusLabel -eq 'Failed'    }).Count
        $avgDur    = [int](($runs | ForEach-Object { [int]$_.DurationSeconds } | Measure-Object -Average).Average)
        $h = [int]($avgDur/3600); $m = [int](($avgDur%3600)/60); $s = $avgDur%60
        $avgFmt = if ($h -gt 0) { "${h}h ${m}m" } elseif ($m -gt 0) { "${m}m ${s}s" } else { "${s}s" }
        $jobStats[$_.Name] = @{ Succeeded=$succeeded; Failed=$failed; AvgDur=$avgFmt }
    }

    # ── Build HTML ────────────────────────────────────────────────────────────
    $sb = [System.Text.StringBuilder]::new()

    [void]$sb.Append(@"
<div class="card">
  <div class="card-header py-2">
    <strong>Job Run History</strong>
    <span class="text-muted small ms-2">Click <strong>+</strong> to expand steps &nbsp;|&nbsp; Click a job name to view on timeline</span>
  </div>
  <div class="card-body p-0" style="max-height:78vh;overflow-y:auto;">
    <table class="table table-sm table-hover mb-0">
      <thead class="table-dark sticky">
        <tr>
          <th style="width:28px"></th>
          <th>Job / Step</th>
          <th class="text-nowrap">Start Time</th>
          <th class="text-nowrap">Duration</th>
          <th style="min-width:90px">Dur.</th>
          <th>Status</th>
          <th>Message</th>
        </tr>
      </thead>
"@)

    foreach ($jobId in $orderedJobIds) {
        $runsForJob  = @($jobRuns | Where-Object { $_.JobId -eq $jobId })
        $jobName     = $runsForJob[0].JobName
        $stats       = $jobStats[$jobId]
        $safeJobName = ConvertTo-HtmlEncoded $jobName

        # Stats badges
        $statBadges = ''
        if ($stats.Succeeded -gt 0) { $statBadges += "<span class=`"badge bs-succeeded ms-1`">$($stats.Succeeded) ok</span>" }
        if ($stats.Failed    -gt 0) { $statBadges += "<span class=`"badge bs-failed ms-1`">$($stats.Failed) failed</span>" }
        $statBadges += "<span class=`"badge bg-secondary ms-1`">avg $($stats.AvgDur)</span>"

        [void]$sb.Append(@"
      <tbody>
        <tr class="job-group-row" id="job-$jobId">
          <td></td>
          <td>
            <span style="cursor:pointer" onclick="navigateToJob('$jobId')" title="View on timeline">$safeJobName</span>
            $statBadges
          </td>
          <td colspan="5"></td>
        </tr>
"@)

        foreach ($run in $runsForJob) {
            $badge    = Get-BadgeClass $run.RunStatusLabel
            $durBar   = Get-DurBar ([int]$run.DurationSeconds)
            $startFmt = $run.StartDateTime.Replace('T',' ')
            $msg      = if ($run.Message.Length -gt 100) { $run.Message.Substring(0,97) + '...' } else { $run.Message }
            $safeMsg  = ConvertTo-HtmlEncoded $msg
            $instId   = $run.InstanceId
            $hasSteps = $stepIndex.ContainsKey($instId)

            $expandBtn = if ($hasSteps) {
                "<button class=`"expand-btn btn btn-sm btn-outline-secondary`" " +
                "onclick=`"toggleSteps('$instId')`" data-toggle=`"$instId`" title=`"Expand steps`">+</button>"
            } else { '' }

            [void]$sb.Append(@"
        <tr>
          <td class="text-center">$expandBtn</td>
          <td class="text-muted small ps-3">$startFmt</td>
          <td class="text-nowrap">$startFmt</td>
          <td class="text-nowrap">$($run.DurationFormatted)</td>
          <td>$durBar</td>
          <td><span class="badge $badge">$($run.RunStatusLabel)</span></td>
          <td class="msg-cell" title="$(ConvertTo-HtmlEncoded $run.Message)">$safeMsg</td>
        </tr>
"@)

            if ($hasSteps) {
                foreach ($step in ($stepIndex[$instId] | Sort-Object { [int]$_.StepId })) {
                    $sBadge   = Get-BadgeClass $step.RunStatusLabel
                    $sDurBar  = Get-DurBar ([int]$step.DurationSeconds)
                    $sStart   = $step.StartDateTime.Replace('T',' ')
                    $sMsg     = if ($step.Message.Length -gt 100) { $step.Message.Substring(0,97) + '...' } else { $step.Message }
                    $sSafeMsg = ConvertTo-HtmlEncoded $sMsg
                    $stepLbl  = ConvertTo-HtmlEncoded "Step $($step.StepId): $($step.StepName)"

                    [void]$sb.Append(@"
        <tr class="step-row d-none" data-stepgroup="$instId">
          <td></td>
          <td class="ps-4 text-muted small">&#x21B3; $stepLbl</td>
          <td class="text-nowrap small">$sStart</td>
          <td class="text-nowrap small">$($step.DurationFormatted)</td>
          <td>$sDurBar</td>
          <td><span class="badge $sBadge">$($step.RunStatusLabel)</span></td>
          <td class="msg-cell" title="$(ConvertTo-HtmlEncoded $step.Message)">$sSafeMsg</td>
        </tr>
"@)
                }
            }
        }

        [void]$sb.Append('      </tbody>')
    }

    [void]$sb.Append('    </table>
  </div>
</div>')

    return $sb.ToString()
}
