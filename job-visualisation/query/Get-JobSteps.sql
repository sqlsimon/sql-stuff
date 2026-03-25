USE msdb;
SET NOCOUNT ON;

SELECT
    CAST(s.job_id AS NVARCHAR(36))  AS JobId,
    s.step_id                        AS StepId,
    s.step_name                      AS StepName,
    s.subsystem                      AS Subsystem,
    ISNULL(s.database_name, '')      AS DatabaseName,
    s.on_success_action              AS OnSuccessAction,
    s.on_fail_action                 AS OnFailAction
FROM dbo.sysjobsteps s
ORDER BY s.job_id, s.step_id;
