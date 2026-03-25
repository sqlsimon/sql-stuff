function Get-HtmlTemplate {
    param(
        [string]$Title,
        [string]$TimelineSection,
        [string]$HistorySection,
        [string]$GeneratedAt,
        [string]$TimelineDate,
        [int]$WindowStartHour,
        [int]$WindowEndHour
    )

    $windowLabel = "$( '{0:D2}:00' -f $WindowStartHour ) - $( '{0:D2}:00' -f $WindowEndHour )"

    return @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$Title</title>
  <link rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
        integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
        crossorigin="anonymous">
  <style>
    body { font-size: 0.875rem; background: #f8f9fa; }

    /* ── Timeline ──────────────────────────────────────────────────────── */
    .timeline-wrap          { overflow-x: auto; }
    .timeline-grid          { min-width: 900px; }
    .tl-axis                { display: flex; margin-left: 210px;
                              border-bottom: 2px solid #dee2e6; padding-bottom: 2px; }
    .tl-axis-label          { flex: 1; text-align: center; font-size: 0.7rem;
                              color: #6c757d; user-select: none; }
    .tl-axis-label:first-child { text-align: left; }
    .tl-axis-label:last-child  { text-align: right; }
    .tl-row                 { display: flex; align-items: center;
                              border-bottom: 1px solid #f0f0f0; min-height: 30px; }
    .tl-row:hover           { background: #f0f4ff; }
    .tl-label               { width: 210px; min-width: 210px; padding: 2px 8px 2px 0;
                              font-size: 0.78rem; overflow: hidden; text-overflow: ellipsis;
                              white-space: nowrap; color: #333; }
    .tl-track               { flex: 1; position: relative; height: 20px; }
    .tl-track-bg            { position: absolute; top: 0; height: 100%;
                              background: rgba(0,0,0,0.03); pointer-events: none; }
    .tl-bar                 { position: absolute; height: 100%; min-width: 6px;
                              border-radius: 3px; opacity: 0.88; cursor: pointer;
                              transition: opacity 0.1s, transform 0.1s; }
    .tl-bar:hover           { opacity: 1; transform: scaleY(1.2); z-index: 10; }

    /* ── Status colours ────────────────────────────────────────────────── */
    .status-succeeded  { background: #198754; }
    .status-failed     { background: #dc3545; }
    .status-retry      { background: #ffc107; }
    .status-cancelled  { background: #6c757d; }
    .status-inprogress { background: #0d6efd;
                         background-image: repeating-linear-gradient(
                           45deg, transparent, transparent 4px,
                           rgba(255,255,255,0.25) 4px, rgba(255,255,255,0.25) 8px); }
    .status-unknown    { background: #adb5bd; }

    /* ── Badge variants (tables) ───────────────────────────────────────── */
    .bs-succeeded  { background-color:#198754; color:#fff; }
    .bs-failed     { background-color:#dc3545; color:#fff; }
    .bs-retry      { background-color:#ffc107; color:#000; }
    .bs-cancelled  { background-color:#6c757d; color:#fff; }
    .bs-inprogress { background-color:#0d6efd; color:#fff; }
    .bs-unknown    { background-color:#adb5bd; color:#fff; }

    /* ── History table ─────────────────────────────────────────────────── */
    .job-group-row td   { background: #e9ecef; font-weight: 600; }
    .step-row           { background: #f8f9fa; }
    .expand-btn         { width: 22px; height: 22px; padding: 0; font-size: 0.85rem;
                          line-height: 1; border-radius: 4px; }
    .dur-wrap  { background:#dee2e6; border-radius:3px; height:6px; min-width:50px; }
    .dur-fill  { height:6px; border-radius:3px; background:#0d6efd; }
    thead.sticky th { position: sticky; top: 0; z-index: 5; }
    .msg-cell { max-width: 320px; overflow: hidden; text-overflow: ellipsis;
                white-space: nowrap; color: #6c757d; font-size: 0.78rem; }

    /* ── Misc ──────────────────────────────────────────────────────────── */
    .card { box-shadow: 0 1px 4px rgba(0,0,0,0.08); }
    .nav-tabs .nav-link { font-weight: 500; }
  </style>
</head>
<body>

<nav class="navbar navbar-dark bg-dark mb-3 py-2">
  <div class="container-fluid">
    <span class="navbar-brand mb-0 h5">&#x1F5C2; SQL Server Job Monitor</span>
    <span class="text-secondary small">Generated: $GeneratedAt &nbsp;|&nbsp; Server: SQLSERVER01</span>
  </div>
</nav>

<div class="container-fluid px-3">

  <ul class="nav nav-tabs mb-3" id="mainTabs" role="tablist">
    <li class="nav-item" role="presentation">
      <button class="nav-link active" id="tab-timeline-btn"
              data-bs-toggle="tab" data-bs-target="#tab-timeline"
              type="button" role="tab">
        &#x1F4C5; Timeline &mdash; $TimelineDate
        <span class="badge bg-secondary ms-1 fw-normal">$windowLabel</span>
      </button>
    </li>
    <li class="nav-item" role="presentation">
      <button class="nav-link" id="tab-history-btn"
              data-bs-toggle="tab" data-bs-target="#tab-history"
              type="button" role="tab">
        &#x1F4CB; Job History
      </button>
    </li>
  </ul>

  <div class="tab-content">
    <div class="tab-pane fade show active" id="tab-timeline" role="tabpanel">
      $TimelineSection
    </div>
    <div class="tab-pane fade" id="tab-history" role="tabpanel">
      $HistorySection
    </div>
  </div>

</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
        integrity="sha384-YvpcrYf0tY3lHB60NNkmXc4s9bIOgUxi8T/jzmBMT3x3YmTqXoTdIOCSmB3RLTM"
        crossorigin="anonymous"></script>
<script>
  // Switch to history tab and scroll to a job's anchor
  function navigateToJob(jobId) {
    var btn = document.getElementById('tab-history-btn');
    bootstrap.Tab.getOrCreateInstance(btn).show();
    setTimeout(function () {
      var el = document.getElementById('job-' + jobId);
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 200);
  }

  // Toggle step rows for a given job run instance
  function toggleSteps(instanceId) {
    var rows = document.querySelectorAll('[data-stepgroup="' + instanceId + '"]');
    var anyHidden = false;
    rows.forEach(function (r) { if (r.classList.contains('d-none')) anyHidden = true; });
    rows.forEach(function (r) { r.classList.toggle('d-none', !anyHidden); });
    var btn = document.querySelector('[data-toggle="' + instanceId + '"]');
    if (btn) btn.textContent = anyHidden ? '-' : '+';
  }
</script>

</body>
</html>
"@
}
