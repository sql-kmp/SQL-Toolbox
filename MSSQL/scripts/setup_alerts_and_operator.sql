/*
	setup_alerts_and_operator.sql

	This script creates recommended SQL Server Agent alerts as well as an operator for alerting.
	It is intended for the initial configuration of newly installed SQL Server instances.

	Parameter(s) to be set in advance:

		@OperatorName	-	A name/designation for the operator which will be configured. Notification configuration will be skipped if NULL.
		@OperatorEMail	-	A semicolon-separated list of email addresses. Notification configuration will be skipped if NULL.
		@AddAOAGAlerts	-	Defines whether alerts related to AlwaysOn availability groups should be created. Default value is 0.
							If SERVERPROPERTY('IsHadrEnabled') equals 0 or is NULL, creation of these warning messages is skipped.

	If any of the parameters is NULL, the configuration of notifications as well as of the failsafe operator will be skipped.

	Changelog
	---------

	2023-01-17	KMP	Name pattern for SQL Server agent service name changed to consider other installation languages (issue #2).
	2022-10-06	KMP	Alert for error 17810 added (dedicated admin connection already exists).
	2021-11-15	KMP	Pre-check if an alert already exists for the specified message_id or severity.
	2021-11-14	KMP	AOAG related alerts added, switched to CURSOR-based processing.
	2021-11-13	KMP	Initial release.

	Known Issues
	------------

	- It is not checked whether the operator is assigned to job agents.
	- Only 1 operator can be created.
	- The created operator automatically becomes the failsafe operator.
	- Nothing included yet related to DBMail.

	The MIT License
	---------------

	Copyright (c) 2021-2022 Kai-Micael Preiﬂ.

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

USE [msdb];
GO

DECLARE @OperatorName NVARCHAR(128) = NULL;
DECLARE @OperatorEMail NVARCHAR(128) = NULL;
DECLARE @AddAOAGAlerts BIT = 1;

/*	*********************************************************************************
	*                    DO NOT CHANGE ANYTHING AFTER THIS LINE!                    *
	********************************************************************************* */

SET NOCOUNT ON;

DECLARE @Alerts TABLE (
	[message_id] INT NOT NULL,
	[severity] INT NOT NULL,
	[alert_name] NVARCHAR(128) NOT NULL
);

INSERT INTO @Alerts ( [message_id], [severity], [alert_name] )
VALUES
	(823, 0, N'Error 823: database integrity at risk'),
	(824, 0, N'Error 824: database integrity at risk'),
	(825, 0, N'Error 825: database integrity at risk'),
	(17810, 0, N'Error 17810: dedicated administrator connection already exists'),
	(0, 17, N'Severity 17 - insufficient resources'),
	(0, 18, N'Severity 18 - non-fatal internal error'),
	(0, 19, N'Severity 19 - fatal resource error'),
	(0, 20, N'Severity 20 - fatal error in the current process'),
	(0, 21, N'Severity 21 - fatal error in database processes'),
	(0, 22, N'Severity 22 - fatal error: table integrity at risk'),
	(0, 23, N'Severity 23 - fatal error: database integrity at risk'),
	(0, 24, N'Severity 24 - fatal error: hardware error'),
	(0, 25, N'Severity 25 - fatal error: system error');

DECLARE @currentAlertMessageId INT;
DECLARE @currentAlertSeverity INT;
DECLARE @currentAlertName NVARCHAR(128);

/*	1a - Check if SQL Server Agent service is up and running.	*/

RAISERROR (N'Checking SQL Server Agent service ...', 10, 1) WITH NOWAIT;

IF NOT EXISTS (
	SELECT 1
		FROM [master].[sys].[dm_server_services] WITH (NOLOCK)
		WHERE [servicename] LIKE 'SQL Server%Agent%'
			AND [status] = 4	-- Running
)
BEGIN
	RAISERROR (N'SQL Server Agent service is not running. Abort execution ...', 16, 1) WITH NOWAIT;
	RETURN;
END;

RAISERROR (N'done.', 10, 1) WITH NOWAIT;

/*	1b - Check if AlwaysOn is enabled.	*/

RAISERROR (N'Checking for HADR availability ...', 10, 1) WITH NOWAIT;

SET @AddAOAGAlerts = COALESCE(@AddAOAGAlerts, 0);

IF (@AddAOAGAlerts = 1)
BEGIN
	IF (CONVERT(INT, PARSENAME(CONVERT(NVARCHAR(128), SERVERPROPERTY('ProductVersion')), 4)) < 11)
	BEGIN
		/* SQL Server 2012 and above only! */
		SET @AddAOAGAlerts = 0;
		RAISERROR (N'AlwaysOn is not implemented in this version of SQL Server. Parameter @AddAOAGAlerts has been reset.', 10, 1) WITH NOWAIT;
	END
	ELSE
	BEGIN
		IF CONVERT(BIT, COALESCE(SERVERPROPERTY('IsHadrEnabled'), 0)) = 0
		BEGIN
			/* HADR is disabled */
			SET @AddAOAGAlerts = 0;
			RAISERROR (N'AlwaysOn is disabled on instance level. Parameter @AddAOAGAlerts has been reset.', 10, 1) WITH NOWAIT;
		END
		ELSE
		BEGIN
			INSERT INTO @Alerts ( [message_id], [severity], [alert_name] )
			VALUES
				(35273, 0, N'AOAG Error 35273: bypassing recovery'),
				(35274, 0, N'AOAG Error 35274: recovery pending'),
				(35275, 0, N'AOAG Error 35275: database potentially damaged'),
				(35254, 0, N'AOAG Error 35254: metadata error'),
				(35279, 0, N'AOAG Error 35279: join rejected'),
				(35276, 0, N'AOAG Error 35276: failed to allocate database'),
				(35264, 0, N'AOAG Error 35264: data movement suspended'),
				(35265, 0, N'AOAG Error 35265: data movement resumed'),
				(41404, 0, N'AOAG Error 41404: AG offline'),
				(41405, 0, N'AOAG Error 41405: not ready for automatic failover');
		END;
	END;
END;

RAISERROR (N'done.', 10, 1) WITH NOWAIT;

/*	2 - Create alerts.	*/

RAISERROR (N'Creating alerts ...', 10, 2) WITH NOWAIT;

DECLARE [alert_cur] CURSOR LOCAL FAST_FORWARD
	FOR SELECT [message_id], [severity], [alert_name] FROM @Alerts;

OPEN [alert_cur];

FETCH NEXT FROM [alert_cur]
	INTO @currentAlertMessageId, @currentAlertSeverity, @currentAlertName;

WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @existingAlertName NVARCHAR(128) = NULL;

	SELECT @existingAlertName = [name]
		FROM [msdb].[dbo].[sysalerts]
		WHERE [message_id] = @currentAlertMessageId
			AND [severity] = @currentAlertSeverity
		OPTION (RECOMPILE);

	IF (@existingAlertName IS NOT NULL)
	BEGIN
		RAISERROR (N'    Alert for message_id %d, severity %d already exists. Skip creation of ''%s''.', 10, 2, @currentAlertMessageId, @currentAlertSeverity, @currentAlertName) WITH NOWAIT;
		
		/* update table variable so that the recipient of the alert notification can be set correctly in step 4: */
		UPDATE @Alerts
			SET [alert_name] = @existingAlertName
			WHERE [message_id] = @currentAlertMessageId
				AND [severity] = @currentAlertSeverity;
	END
	ELSE
	BEGIN
		IF EXISTS (
			SELECT [name]
				FROM [msdb].[dbo].[sysalerts]
				WHERE [name] = @currentAlertName
		)
		EXEC [msdb].[dbo].[sp_delete_alert] @name = @currentAlertName;

		EXEC [msdb].[dbo].[sp_add_alert]
			@name = @currentAlertName,
			@message_id = @currentAlertMessageId,
			@severity = @currentAlertSeverity,
			@enabled = 1,
			@delay_between_responses = 0,
			@include_event_description_in = 1;

		RAISERROR (N'    Alert ''%s'' for message_id %d, severity %d created.', 10, 2, @currentAlertName, @currentAlertMessageId, @currentAlertSeverity) WITH NOWAIT;
	END;

	FETCH NEXT FROM [alert_cur]
		INTO @currentAlertMessageId, @currentAlertSeverity, @currentAlertName;
END;

CLOSE [alert_cur];
DEALLOCATE [alert_cur];

RAISERROR (N'done.', 10, 2) WITH NOWAIT;

/*	3 - Create operator.	*/

IF ( COALESCE(@OperatorName, N'') = N''	OR COALESCE(@OperatorEMail, N'') = N'')
BEGIN
	RAISERROR (N'Skipping operator and notification configuration.', 10, 3) WITH NOWAIT;
	RETURN;
END;

RAISERROR (N'Unset failsafe operator, if already set ...', 10, 3) WITH NOWAIT;

EXEC [master].[dbo].[sp_MSsetalertinfo]
	@failsafeoperator = N'',
	@notificationmethod = 0;

RAISERROR (N'done.', 10, 3) WITH NOWAIT;

RAISERROR (N'Create operator ...', 10, 3) WITH NOWAIT;

IF  EXISTS (
	SELECT 1
		FROM [msdb].[dbo].[sysoperators]
		WHERE [name] = @OperatorName
)
EXEC [msdb].[dbo].[sp_delete_operator] @name = @OperatorName;

EXEC [msdb].[dbo].[sp_add_operator]
	@name = @OperatorName,
	@enabled = 1,
	@email_address = @OperatorEMail;

RAISERROR (N'done.', 10, 3) WITH NOWAIT;

RAISERROR (N'Set failsafe operator ...', 10, 3) WITH NOWAIT;

EXEC [master].[dbo].[sp_MSsetalertinfo]
	@failsafeoperator = @OperatorName,
	@notificationmethod = 1;

RAISERROR (N'done.', 10, 3) WITH NOWAIT;

/*	4 - Configure alert notifications.	*/

RAISERROR (N'Configure alert notifications ...', 10, 4) WITH NOWAIT;

DECLARE [alert_cur] CURSOR LOCAL FAST_FORWARD
FOR SELECT [alert_name] FROM @Alerts;

OPEN [alert_cur];

FETCH NEXT FROM [alert_cur]
	INTO @currentAlertName;

WHILE @@FETCH_STATUS = 0
BEGIN
	RAISERROR (N'    processing ''%s''', 10, 2, @currentAlertName) WITH NOWAIT;

	EXEC [msdb].[dbo].[sp_add_notification]
		@alert_name = @currentAlertName,
		@operator_name = @OperatorName,
		@notification_method = 1;

	FETCH NEXT FROM [alert_cur]
		INTO @currentAlertName;
END;

CLOSE  [alert_cur];
DEALLOCATE [alert_cur];

RAISERROR (N'done.', 10, 4) WITH NOWAIT;

/*	5 - Final setting (replace runtime tokens).	*/

RAISERROR (N'Enable ''Replace tokens for all job responses to alerts'' option ...', 10, 5) WITH NOWAIT;

EXEC [msdb].[dbo].[sp_set_sqlagent_properties] @alert_replace_runtime_tokens = 1;

RAISERROR (N'done.', 10, 5) WITH NOWAIT;
