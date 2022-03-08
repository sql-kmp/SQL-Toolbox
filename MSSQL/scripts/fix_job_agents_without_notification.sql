/*
	fix_job_agents_without_notification.sql

	This script fixes job agents w/o on-failure notifications. If there are no or more than 1 operators, the script terminates.

	Parameter(s) to be set in advance: None.

	Changelog
	---------
	
	2021-11-13	KMP	Initial release.
	
	Known Issues
	------------

	- Exactly 1 operator may be defined, only.
	- Nothing included yet related to DBMail.

	The MIT License
	---------------

	Copyright (c) 2021-2022 Kai-Micael Preiß.

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

*/

USE [master];
GO

SET NOCOUNT ON;

/*	1 - Check if SQL Server Agent service is up and running.	*/

RAISERROR (N'Check SQL Server Agent service ...', 10, 1) WITH NOWAIT;

IF NOT EXISTS (
	SELECT 1
	FROM [master].[sys].[dm_server_services] WITH (NOLOCK)
	WHERE [servicename] LIKE 'SQL Server Agent%'
		AND [status] = 4	-- Running
)
BEGIN
	RAISERROR (N'SQL Server Agent service is not running. Abort execution ...', 16, 1) WITH NOWAIT;
	RETURN;
END;

RAISERROR (N'done.', 10, 1) WITH NOWAIT;

/*	2 - Get the operator's name.	*/

RAISERROR (N'Get the operator''s  name/designation ...', 10, 2) WITH NOWAIT;

DECLARE @operatorCount INT;
DECLARE @operatorName NVARCHAR(128);

SELECT @operatorCount = COUNT(*)
FROM [msdb].[dbo].[sysoperators]
OPTION (RECOMPILE);

IF (@operatorCount = 0)
BEGIN
	RAISERROR (N'No operators found. Abort execution ...', 16, 2) WITH NOWAIT;
	RETURN;
END
ELSE IF (@operatorCount > 1)
BEGIN
	RAISERROR (N'%d operators found. Abort execution ...', 16, 2, @operatorCount) WITH NOWAIT;
	RETURN;
END
ELSE
BEGIN
	SELECT @operatorName = [name]
	FROM [msdb].[dbo].[sysoperators]
	OPTION (RECOMPILE);
END;

RAISERROR (N'done.', 10, 2) WITH NOWAIT;

/*	3 - Set recipient for notifications.	*/

RAISERROR (N'Set operator ''%s'' as recipient for job agent notifications ...', 10, 3, @operatorName) WITH NOWAIT;

DECLARE @jid AS UNIQUEIDENTIFIER;

DECLARE [job_cursor] CURSOR
FOR SELECT [job_id] FROM [msdb].[dbo].[sysjobs];

OPEN [job_cursor];

FETCH NEXT FROM [job_cursor]
INTO @jid;

WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC [msdb].[dbo].[sp_update_job] @job_id = @jid,
		@notify_level_email = 2,						-- on failure
		@notify_email_operator_name = @operatorName;
	
	FETCH NEXT FROM [job_cursor]
	INTO @jid;
END;

CLOSE [job_cursor];
DEALLOCATE [job_cursor];

RAISERROR (N'done.', 10, 3) WITH NOWAIT;