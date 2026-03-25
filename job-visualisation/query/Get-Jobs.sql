USE msdb;
SET NOCOUNT ON;

SELECT
    CAST(j.job_id AS NVARCHAR(36))          AS JobId,
    j.name                                   AS JobName,
    ISNULL(c.name, 'Uncategorized')          AS Category,
    j.enabled                                AS Enabled,
    ISNULL(j.description, '')                AS Description,
    ISNULL(SUSER_SNAME(j.owner_sid), '')     AS Owner
FROM dbo.sysjobs j
LEFT JOIN dbo.syscategories c ON j.category_id = c.category_id
ORDER BY j.name;
