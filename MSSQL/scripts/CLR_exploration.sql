/*
    CLR_exploration.sql

    The script provides an overview of user-defined assemblies.

    Changelog
    ---------

    2024-03-06  KMP Initial release.

    Known Issues
    ------------

    - Hashes must be calculated row by row with a CURSOR due to
      error 8152 (String or binary data would be truncated.),
      if [content] is too large.
    - Within the dynamic SQL statement you need to leave the tabs
      in place. If you would substitue them by spaces, the statement
      becomes too long for [sp_MSforeachdb].

    The MIT License
    ---------------

    Copyright (c) 2024 Kai-Micael Preiß.

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

SELECT @@SERVERNAME [srv],
        @@VERSION [version]
    OPTION (RECOMPILE);

SELECT @@SERVERNAME [srv],
        [name],
        [description],
        [value],
        [value_in_use]
    FROM [master].[sys].[configurations]
    WHERE [name] LIKE '%clr%'
    OPTION (RECOMPILE);

CREATE TABLE [#assemblies] (
    [id] INT NOT NULL IDENTITY(1, 1) PRIMARY KEY,
    [srv] SYSNAME NOT NULL,
    [database_name] SYSNAME NOT NULL,
    [assembly_name] SYSNAME NOT NULL,
    [principal_id] INT NOT NULL,
    [principal] SYSNAME NULL,
    [assembly_id] INT NOT NULL,
    [clr_name] NVARCHAR(4000) NULL,
    [permission_set_desc] NVARCHAR(60),
    [is_visible] BIT NOT NULL,
    [assembly_filename] NVARCHAR(260) NULL,
    [content] VARBINARY(MAX) NULL,
    [assembly_hash] VARBINARY(8000) NULL,
    [content_bytes] AS DATALENGTH([content])
);

CREATE TABLE [#assembly_modules] (
    [srv] SYSNAME NOT NULL,
    [database_name] SYSNAME NOT NULL,
    [object_name] NVARCHAR(512) NULL,
    [assembly_name] SYSNAME NULL,
    [assembly_class] SYSNAME NULL,
    [assembly_method] SYSNAME NULL
);

CREATE TABLE [#trusted_assemblies] (
    [srv] SYSNAME NOT NULL,
    [database_name] SYSNAME NOT NULL,
    [hash] VARBINARY(8000) NULL,
    [description] NVARCHAR(4000) NULL,
    [create_date] DATETIME2 NULL,
    [created_by] SYSNAME NULL
);

EXEC [master].[sys].[sp_MSforeachdb] N'USE [?];

INSERT INTO [#assemblies]
	SELECT @@SERVERNAME,
			DB_NAME(),
			[a].[name],
			[a].[principal_id],
			USER_NAME([a].[principal_id]),
			[a].[assembly_id],
			[a].[clr_name],
			[a].[permission_set_desc],
			[a].[is_visible],
			[af].[name],
			[af].[content],
			NULL				/* [assembly_hash] will be calculated in the next step */
		FROM [sys].[assemblies] [a]
			LEFT JOIN [sys].[assembly_files] [af]
				ON [a].[assembly_id] = [af].[assembly_id]
		WHERE [a].[is_user_defined] = 1
		OPTION (RECOMPILE);

DECLARE CRSR_ASS CURSOR FORWARD_ONLY
	FOR SELECT [id], [assembly_hash] FROM [#assemblies]
	FOR UPDATE OF [assembly_hash];

OPEN CRSR_ASS;

DECLARE @id TINYINT, @assembly_hash VARBINARY(8000);

FETCH NEXT FROM CRSR_ASS INTO @id, @assembly_hash;

WHILE @@FETCH_STATUS = 0
BEGIN
	UPDATE [#assemblies]
		SET [assembly_hash] = HASHBYTES(''SHA2_512'', [content])
		WHERE CURRENT OF CRSR_ASS;
	
	FETCH NEXT FROM CRSR_ASS INTO @id, @assembly_hash;
END;

CLOSE CRSR_ASS;
DEALLOCATE CRSR_ASS;

INSERT INTO [#assembly_modules]
	SELECT @@SERVERNAME,
			DB_NAME(),
			QUOTENAME(SCHEMA_NAME([o].[schema_id])) + N''.''
				+ QUOTENAME([o].[name]),
			[a].[name],
			[am].[assembly_class],
			[am].[assembly_method]
		FROM [sys].[assembly_modules] [am]
			LEFT JOIN [sys].[objects] [o]
				ON [am].[object_id] = [o].[object_id]
			LEFT JOIN [sys].[assemblies] [a]
				ON [am].[assembly_id] = [a].[assembly_id]
		OPTION (RECOMPILE);

IF ( CONVERT(TINYINT, SERVERPROPERTY(''ProductMajorVersion'')) >= 14 )
BEGIN
	INSERT INTO [#trusted_assemblies]
		SELECT @@SERVERNAME,
				DB_NAME(),
				[hash],
				[description],
				[create_date],
				[created_by]
			FROM [sys].[trusted_assemblies]
			OPTION (RECOMPILE);
END;
';

SELECT [a].[srv],
        [a].[database_name],
        [a].[assembly_name],
        [a].[principal],
        [a].[clr_name],
        [a].[permission_set_desc],
        [a].[is_visible],
        [a].[assembly_filename],
        [a].[assembly_hash],
        [a].[content_bytes],
        CASE
            WHEN [ta].[hash] IS NULL THEN 0
            ELSE 1
        END [is_trusted],
        [ta].[create_date],
        [ta].[created_by]
    FROM [#assemblies] [a]
        LEFT JOIN [#trusted_assemblies] [ta]
            ON EXISTS (
                SELECT [a].[assembly_hash], [a].[srv], [a].[database_name]
                INTERSECT
                SELECT [ta].[hash], [ta].[srv], [ta].[database_name]
            )
    ORDER BY [a].[srv], [a].[database_name], [a].[assembly_name]
    OPTION (RECOMPILE);

SELECT *
    FROM [#assembly_modules];

DROP TABLE [#assemblies];
DROP TABLE [#assembly_modules];
DROP TABLE [#trusted_assemblies];
