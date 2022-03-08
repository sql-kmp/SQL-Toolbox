/*
	configure_Veeam_permissions.sql

	This script configures Veeam Backup & Replication permissions acc. to
	https://helpcenter.veeam.com/docs/backup/vsphere/required_permissions.html?ver=110#vesql.
	
	First, specify the name of the Veeam service account (@VeeamServiceAccount). If this parameter
	is NULL, the execution of the script will be aborted.

	The script checks if this server principal already exists. If not, the login will be created.

	After that, every database except tempdb that is in READ_WRITE status is checked to see	if a
	database user already exists that is assigned to the specified login. If not, a database user
	is created and assigned accordingly.

	Changelog
	---------

	2022-03-08	KMP	Initial release.

	Known Issues
	------------

	- The script does not check if the given login owns the database.

	The MIT License
	---------------

	Copyright (c) 2022 Kai-Micael Preiﬂ.

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

DECLARE @VeeamServiceAccount NVARCHAR(128) = NULL;		/* Specify Veeam service account. */

/*	*********************************************************************************
	*                    DO NOT CHANGE ANYTHING AFTER THIS LINE!                    *
	********************************************************************************* */

SET NOCOUNT ON;

DECLARE @stmt NVARCHAR(MAX) = NULL;
DECLARE @LF NCHAR(2) = NCHAR(13) + NCHAR(10);	/* line feed */

IF @VeeamServiceAccount IS NULL
BEGIN
	RAISERROR (N'Missing parameter for Veeam service account. Execution will be canceled!', 16, 1) WITH NOWAIT;
	RETURN;
END;

IF @VeeamServiceAccount = SUSER_SNAME()
BEGIN
	RAISERROR (N'You''re trying to configure privileges for the same account you''re currently using. Execution will be canceled!', 16, 1) WITH NOWAIT;
	RETURN;
END;

IF NOT EXISTS (
	SELECT *
		FROM [master].[sys].[server_principals]
		WHERE [name] = @VeeamServiceAccount
)
BEGIN
	/* create login */
	SET @stmt = N'CREATE LOGIN ' + QUOTENAME(@VeeamServiceAccount) + @LF
				+ N'FROM WINDOWS' + @LF
				+ N'WITH DEFAULT_DATABASE = [master];'
	EXEC sp_executesql @stmt;
END;

IF @@ERROR != 0 RETURN;

/* add login to server role(s) */
SET @stmt = N'ALTER SERVER ROLE [dbcreator] ADD MEMBER ' + QUOTENAME(@VeeamServiceAccount) + N';'
EXEC sp_executesql @stmt;

IF @@ERROR != 0 RETURN;

/* Securables */
SET @stmt = N'GRANT CONNECT SQL TO ' + QUOTENAME(@VeeamServiceAccount) + N';' + @LF
			+ N'GRANT VIEW ANY DEFINITION TO ' + QUOTENAME(@VeeamServiceAccount) + N';' + @LF
			+ N'GRANT VIEW SERVER STATE TO ' + QUOTENAME(@VeeamServiceAccount) + N';'	
EXEC sp_executesql @stmt;

IF @@ERROR != 0 RETURN;
	
/* create/map user in all databases, except tempdb, if not mapped to a login yet */
SET @stmt = N'USE [?];' + @LF
		+ N'IF NOT EXISTS (' + @LF
		+ N'	SELECT *' + @LF
		+ N'		FROM [sys].[database_principals] AS [dp]' + @LF
		+ N'			INNER JOIN [master].[sys].[server_principals] AS [sp] ON [dp].[sid] = [sp].[sid]' + @LF
		+ N'		WHERE [sp].[name] = N''' + @VeeamServiceAccount + N'''' + @LF
		+ N')' + @LF
		+ N'BEGIN' + @LF
		+ N'	IF DB_NAME() != N''tempdb'' AND DATABASEPROPERTYEX(DB_NAME(), ''Updateability'') = ''READ_WRITE''' + @LF
		+ N'	BEGIN' + @LF
		+ N'		CREATE USER ' + QUOTENAME(@VeeamServiceAccount) + @LF
		+ N'			FOR LOGIN ' + QUOTENAME(@VeeamServiceAccount) + N';' + @LF
		+ N'	END;' + @LF
		+ N'END;' + @LF + @LF
		+ N'IF @@ERROR != 0 RETURN;' + @LF + @LF
		+ N'DECLARE @stmt NVARCHAR(MAX);' + @LF
		+ N'DECLARE @dbuser NVARCHAR(128);' + @LF
		+ N'SELECT @dbuser = [dp].[name]' + @LF
		+ N'	FROM [sys].[database_principals] AS [dp]' + @LF
		+ N'		INNER JOIN [master].[sys].[server_principals] AS [sp] ON [dp].[sid] = [sp].[sid]' + @LF
		+ N'	WHERE [sp].[name] = N''' + @VeeamServiceAccount + N''';' + @LF + @LF
		+ N'IF @@ERROR != 0 RETURN;' + @LF + @LF
		+ N'IF DB_NAME() != N''tempdb'' AND DATABASEPROPERTYEX(DB_NAME(), ''Updateability'') = ''READ_WRITE''' + @LF
		+ N'BEGIN' + @LF
		+ N'	SET @stmt = N''ALTER ROLE [db_backupoperator] ADD MEMBER '' + QUOTENAME(@dbuser) + N'';'';' + @LF
		+ N'	EXEC sp_executesql @stmt;' + @LF
		+ N'END;' + @LF
		+ N'IF @@ERROR != 0 RETURN;' + @LF + @LF
		+ N'IF DB_NAME() IN (N''master'', N''msdb'')  AND DATABASEPROPERTYEX(DB_NAME(), ''Updateability'') = ''READ_WRITE''' + @LF
		+ N'BEGIN' + @LF
		+ N'	SET @stmt = N''ALTER ROLE [db_datareader] ADD MEMBER '' + QUOTENAME(@dbuser) + N'';'';' + @LF
		+ N'	EXEC sp_executesql @stmt;' + @LF
		+ N'END;' + @LF
		+ N'IF @@ERROR != 0 RETURN;' + @LF + @LF
		+ N'IF DB_NAME() = N''msdb'' AND DATABASEPROPERTYEX(DB_NAME(), ''Updateability'') = ''READ_WRITE''' + @LF
		+ N'BEGIN' + @LF
		+ N'	SET @stmt = N''ALTER ROLE [db_datawriter] ADD MEMBER '' + QUOTENAME(@dbuser) + N'';'';' + @LF
		+ N'	EXEC sp_executesql @stmt;' + @LF
		+ N'END;' + @LF
		+ N'IF @@ERROR != 0 RETURN;' + @LF + @LF
		+ N'IF DB_NAME() NOT IN (N''master'', N''msdb'', ''tempdb'') AND DATABASEPROPERTYEX(DB_NAME(), ''Updateability'') = ''READ_WRITE''' + @LF
		+ N'BEGIN' + @LF
		+ N'	SET @stmt = N''ALTER ROLE [db_denydatareader] ADD MEMBER '' + QUOTENAME(@dbuser) + N'';'';' + @LF
		+ N'	EXEC sp_executesql @stmt;' + @LF
		+ N'END;'
EXEC sp_MSforeachdb @stmt;
