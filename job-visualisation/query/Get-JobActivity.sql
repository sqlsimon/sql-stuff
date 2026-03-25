USE msdb;
SET NOCOUNT ON;

-- Only the most recent SQL Agent session to avoid duplicates from service restarts
DECLARE @SessionId INT = (
    SELECT TOP 1 session_id
    FROM dbo.syssessions
    ORDER BY agent_start_date DESC
);

SELECT
    CAST(ja.job_id AS NVARCHAR(36))                                         AS JobId,
    j.name                                                                   AS JobName,
    ISNULL(CONVERT(NVARCHAR(23), ja.run_requested_date,   126), '')          AS RunRequestedDate,
    ISNULL(CONVERT(NVARCHAR(23), ja.start_execution_date, 126), '')          AS StartExecutionDate,
    ISNULL(CONVERT(NVARCHAR(23), ja.stop_execution_date,  126), '')          AS StopExecutionDate,
    CASE
        WHEN ja.start_execution_date IS NOT NULL
         AND ja.stop_execution_date  IS NULL
        THEN 'TRUE' ELSE 'FALSE'
    END                                                                      AS IsRunning,
    ISNULL(CONVERT(NVARCHAR(23), ja.next_scheduled_run_date, 126), '')       AS NextScheduledRun
FROM dbo.sysjobactivity ja
JOIN dbo.sysjobs j ON ja.job_id = j.job_id
WHERE ja.session_id = @SessionId
  AND ja.run_requested_date IS NOT NULL
ORDER BY j.name;
