USE msdb;
SET NOCOUNT ON;

-- Parameters via sqlcmd variable substitution: $(DaysBack)
-- e.g. sqlcmd -v DaysBack=30
DECLARE @CutoffDate INT =
    CAST(CONVERT(VARCHAR(8), DATEADD(DAY, -$(DaysBack), GETDATE()), 112) AS INT);

SELECT
    sh.instance_id                              AS InstanceId,
    CAST(sh.job_id AS NVARCHAR(36))             AS JobId,
    j.name                                      AS JobName,
    sh.step_id                                  AS StepId,
    ISNULL(sh.step_name, '(Job outcome)')       AS StepName,
    sh.run_status                               AS RunStatus,
    CASE sh.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Cancelled'
        WHEN 4 THEN 'InProgress'
        ELSE       'Unknown'
    END                                         AS RunStatusLabel,
    -- Convert integer run_date (yyyyMMdd) + run_time (HHmmss) to ISO 8601 string
    CONVERT(NVARCHAR(23),
        DATETIMEFROMPARTS(
            sh.run_date / 10000,
            sh.run_date % 10000 / 100,
            sh.run_date % 100,
            sh.run_time / 10000,
            sh.run_time % 10000 / 100,
            sh.run_time % 100,
            0
        ), 126)                                 AS StartDateTime,
    -- Convert run_duration (stored as HHmmss integer) to total seconds
    (sh.run_duration / 10000) * 3600
        + ((sh.run_duration % 10000) / 100) * 60
        + (sh.run_duration % 100)              AS DurationSeconds,
    -- Human-readable HH:MM:SS
    RIGHT('00' + CAST(sh.run_duration / 10000 AS VARCHAR), 3) + ':' +
    RIGHT('00' + CAST((sh.run_duration % 10000) / 100 AS VARCHAR), 2) + ':' +
    RIGHT('00' + CAST(sh.run_duration % 100 AS VARCHAR), 2)
                                                AS DurationFormatted,
    -- Link step rows back to their parent job-level row (step_id = 0).
    -- The summary row always has the highest instance_id in a run, so we find
    -- the nearest step_id=0 row whose instance_id is >= the current row.
    COALESCE(
        (SELECT TOP 1 sh2.instance_id
         FROM dbo.sysjobhistory sh2
         WHERE sh2.job_id   = sh.job_id
           AND sh2.step_id  = 0
           AND sh2.run_date = sh.run_date
           AND sh2.instance_id >= sh.instance_id
         ORDER BY sh2.instance_id ASC),
        sh.instance_id
    )                                           AS JobRunInstanceId,
    LEFT(ISNULL(sh.message, ''), 500)           AS Message,
    sh.retries_attempted                        AS RetryCount,
    ISNULL(sh.server, @@SERVERNAME)             AS ServerName
FROM dbo.sysjobhistory sh
JOIN dbo.sysjobs j ON sh.job_id = j.job_id
WHERE sh.run_date >= @CutoffDate
ORDER BY j.name, sh.run_date DESC, sh.run_time DESC, sh.step_id;
