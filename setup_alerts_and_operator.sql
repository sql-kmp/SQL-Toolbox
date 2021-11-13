USE [master];
GO

/*
	setup_alerts_and_operator.sql

	This script creates recommended SQL Server Agent alerts as well as an operator for alerting.
	It is intended for the initial configuration of newly installed SQL Server instances.

	Parameter(s) to be set in advance:

		@OperatorName	- A name/designation for the operator which will be configured. Notification configuration will be skipped if NULL.
		@OperatorEMail	- A semicolon-separated list of email addresses. Notification configuration will be skipped if NULL.

	If any of the parameters is NULL, the configuration of notifications as well as of the failsafe operator will be skipped.

	Changelog
	---------

	2021-11-13	KMP	Initial release.

	Known Issues
	------------

	- The script does not check in advance whether there has been identical alerts already created, just with a different name.
	- It is not checked whether the operator is assigned to job agents.
	- Only 1 operator can be created.
	- The created operator automatically becomes the failsafe operator.
	- Nothing included yet related to DBMail.

	The MIT License
	---------------

	Copyright (c) 2021 Kai-Micael Preiﬂ.

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

DECLARE @OperatorName NVARCHAR(128) = NULL;
DECLARE @OperatorEMail NVARCHAR(128) = NULL;

/*	*********************************************************************************
	DO NOT CHANGE ANYTHING AFTER THIS LINE!
	********************************************************************************* */

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

/*	2 - Create alerts.	*/

RAISERROR (N'Creating alerts ...', 10, 2) WITH NOWAIT;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Error 823: database integrity at risk'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Error 823: database integrity at risk';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Error 823: database integrity at risk', 
	@message_id = 823, 
	@severity = 0, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Error 824: database integrity at risk'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Error 824: database integrity at risk';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Error 824: database integrity at risk', 
	@message_id = 824, 
	@severity = 0, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Error 825: database integrity at risk'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Error 825: database integrity at risk';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Error 825: database integrity at risk', 
	@message_id = 825, 
	@severity = 0, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Severity 17 - insufficient resources'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Severity 17 - insufficient resources';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Severity 17 - insufficient resources', 
	@message_id = 0, 
	@severity = 17, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Severity 18 - non-fatal internal error'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Severity 18 - non-fatal internal error';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Severity 18 - non-fatal internal error', 
	@message_id = 0, 
	@severity = 18, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Severity 19 - fatal resource error'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Severity 19 - fatal resource error';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Severity 19 - fatal resource error', 
	@message_id = 0, 
	@severity = 19, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Severity 20 - fatal error in the current process'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Severity 20 - fatal error in the current process';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Severity 20 - fatal error in the current process', 
	@message_id = 0, 
	@severity = 20, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Severity 21 - fatal error in database processes'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Severity 21 - fatal error in database processes';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Severity 21 - fatal error in database processes', 
	@message_id = 0, 
	@severity = 21, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Severity 22 - fatal error: table integrity at risk'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Severity 22 - fatal error: table integrity at risk';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Severity 22 - fatal error: table integrity at risk', 
	@message_id = 0, 
	@severity = 22, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Severity 23 - fatal error: database integrity at risk'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Severity 23 - fatal error: database integrity at risk';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Severity 23 - fatal error: database integrity at risk', 
	@message_id = 0, 
	@severity = 23, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Severity 24 - fatal error: hardware error'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Severity 24 - fatal error: hardware error';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Severity 24 - fatal error: hardware error', 
	@message_id = 0, 
	@severity = 24, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

IF EXISTS (
	SELECT [name]
	FROM [msdb].[dbo].[sysalerts]
	WHERE [name] = N'Severity 25 - fatal error: system error'
)
EXEC [msdb].[dbo].[sp_delete_alert] @name = N'Severity 25 - fatal error: system error';

EXEC [msdb].[dbo].[sp_add_alert]
	@name = N'Severity 25 - fatal error: system error', 
	@message_id = 0, 
	@severity = 25, 
	@enabled = 1, 
	@delay_between_responses = 0, 
	@include_event_description_in = 1;

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

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Error 823: database integrity at risk',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Error 824: database integrity at risk',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Error 825: database integrity at risk',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Severity 17 - insufficient resources',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Severity 18 - non-fatal internal error',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Severity 19 - fatal resource error',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Severity 20 - fatal error in the current process',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Severity 21 - fatal error in database processes',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Severity 22 - fatal error: table integrity at risk',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Severity 23 - fatal error: database integrity at risk',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Severity 24 - fatal error: hardware error',
	@operator_name = @OperatorName,
	@notification_method = 1;

EXEC [msdb].[dbo].[sp_add_notification]
	@alert_name = N'Severity 25 - fatal error: system error',
	@operator_name = @OperatorName,
	@notification_method = 1;

RAISERROR (N'done.', 10, 4) WITH NOWAIT;

/*	5 - Final setting (replace runtime tokens).	*/

EXEC [msdb].[dbo].[sp_set_sqlagent_properties] @alert_replace_runtime_tokens = 1;

