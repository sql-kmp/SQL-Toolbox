/*
    fix_untrusted_constraints.sql

    This script searches for untrusted foreign keys as well as check constraints
    and generates a SQL query to fix these constraints.

    Parameter(s) to set or changes to make in advance:

        None.

    Changelog
    ---------
    
	2023-06-14	KMP temporary table for results added
    2023-02-02  KMP check each database (using sp_MSforeachdb), fully qualified object names
    2023-01-18  KMP Initial release.
    
    Known Issues
    ------------

    None.

    The MIT License
    ---------------

    Copyright (c) 2023 Kai-Micael Preiß.

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

CREATE TABLE [#tmpResults] (
    [database] SYSNAME NOT NULL,
    [untrusted_constraint] SYSNAME NOT NULL,
	[type] VARCHAR(30) NOT NULL,
	[fix] NVARCHAR(4000) NULL
);

EXEC sp_MSforeachdb N'
USE [?];

SET NOCOUNT ON;

INSERT INTO [#tmpResults]
	SELECT DB_NAME() [database],
			QUOTENAME([s].[name]) + N''.'' + QUOTENAME([o].[name]) + N''.'' + QUOTENAME([fk].[name]) AS [untrusted_foreign_key],
			''FOREIGN KEY CONSTRAINT'',
			N''ALTER TABLE '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([s].[name]) + N''.'' + QUOTENAME([o].[name])
				+ N'' WITH CHECK CHECK CONSTRAINT '' + QUOTENAME([fk].[name]) + N'';'' AS [fix]
		FROM [sys].[foreign_keys] AS [fk]
			INNER JOIN [sys].[objects] AS [o] ON [fk].[parent_object_id] = [o].[object_id]
			INNER JOIN [sys].[schemas] AS [s] ON [o].[schema_id] = [s].[schema_id]
		WHERE [fk].[is_not_trusted] = 1
			AND [fk].[is_not_for_replication] = 0        /* exclude keys that are relevant for replication! */
		OPTION (RECOMPILE);

INSERT INTO [#tmpResults]
	SELECT DB_NAME() [database],
			QUOTENAME([s].[name]) + N''.'' + QUOTENAME([o].[name]) + N''.'' + QUOTENAME([cc].[name]) AS [untrusted_check_constraint],
			''CHECK CONSTRAINT'',
			N''ALTER TABLE '' + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([s].[name]) + N''.'' + QUOTENAME([o].[name])
				+ N'' WITH CHECK CHECK CONSTRAINT '' + QUOTENAME([cc].[name]) + N'';'' AS [fix]
		FROM [sys].[check_constraints] AS [cc]
			INNER JOIN [sys].[objects] [o] ON [cc].[parent_object_id] = [o].[object_id]
			INNER JOIN [sys].[schemas] [s] ON [o].[schema_id] = [s].[schema_id]
		WHERE [cc].[is_not_trusted] = 1
			AND [cc].[is_not_for_replication] = 0        /* exclude keys that are relevant for replication! */
			AND [cc].[is_disabled] = 0
		OPTION (RECOMPILE);
';

SELECT *
    FROM [#tmpResults]
	ORDER BY [database], [untrusted_constraint]
	OPTION (RECOMPILE);

DROP TABLE [#tmpResults];
