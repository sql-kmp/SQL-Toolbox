/*
    linked_server_usage.sql

    This script checks whether the name of configured linked servers is contained in the definition of database objects.

    Parameter(s) to set or changes to make in advance:

        None.

    Changelog
    ---------
    
    2025-04-10  KMP Initial release.

    Known Issues
    ------------

    The script scans all databases and their object definitions and can therefore take a while.

    There is a certain probability of false positives, for example if the name of the linked server is in a comment or
    if there are other objects with this name.

    It's up to the user to check whether the linked server is actually used in the objects found.

    As additional indicators, the system checks whether calls to OPENQUERY() exist in the object definition and
    also returns a small code snippet containing the 1st occurrence of the linked server.

    The MIT License
    ---------------

    Copyright (c) 2025-2026, Kai-Micael Preiﬂ.

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

IF OBJECT_ID(N'tempdb..#tmpLinkedServers') IS NOT NULL
    DROP TABLE [#tmpLinkedServers];

IF OBJECT_ID(N'tempdb..#tmpResults') IS NOT NULL
    DROP TABLE [#tmpResults];
GO

CREATE TABLE [#tmpLinkedServers] (
    [linked_server_name] sysname NOT NULL,
    [product] sysname NOT NULL,
    [provider] sysname NOT NULL,
    [data_source] nvarchar(4000) NULL,
    [catalog] sysname NULL
);
GO

CREATE TABLE [#tmpResults] (
    [linked_server_name] sysname NOT NULL,
    [database_name] sysname NOT NULL,
    [database_state] nvarchar(60) NULL,
    [object] sysname NULL,
    [object_type] nvarchar(60) NULL,
    [is_ms_shipped] bit NULL,
    [definition] nvarchar(max) NULL
);
GO

INSERT INTO [#tmpLinkedServers] (
    [linked_server_name],
    [product],
    [provider],
    [data_source],
    [catalog]
) SELECT [name],
        [product],
        [provider],
        [data_source],
        [catalog]
    FROM [master].[sys].[servers]
    WHERE [is_linked] = 1
    OPTION (RECOMPILE);
GO

DECLARE @stmt nvarchar(4000);
DECLARE @db sysname;
DECLARE @db_state nvarchar(60);

DECLARE [db_crsr] CURSOR FAST_FORWARD FOR
    SELECT [name], [state_desc]
        FROM [master].[sys].[databases]
        OPTION (RECOMPILE);

OPEN [db_crsr];
FETCH NEXT FROM [db_crsr] INTO @db, @db_state;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @stmt = N'USE ' + QUOTENAME(@db) + N';

;WITH [results] AS (
    SELECT [srv].[linked_server_name],
            DB_NAME() [database_name],
            N''' + @db_state + N''' [database_state],
            QUOTENAME([s].[name]) + N''.'' + QUOTENAME([o].[name]) [object],
            [o].[type_desc] [object_type],
            [o].[is_ms_shipped],
            [asm].[definition] [definition]
        FROM [#tmpLinkedServers] [srv]
            INNER JOIN [sys].[all_sql_modules] [asm]
                ON [asm].[definition] LIKE N''%'' + [srv].[linked_server_name] COLLATE DATABASE_DEFAULT + N''%''
            INNER JOIN [sys].[objects] [o]
                ON [o].[object_id] = [asm].[object_id]
            INNER JOIN [sys].[schemas] [s]
                ON [s].[schema_id] = [o].[schema_id]

    UNION ALL

    SELECT [srv].[linked_server_name],
            DB_NAME() [database_name],
            N''' + @db_state + N''' [database_state],
            QUOTENAME([s].[name]) + N''.'' + QUOTENAME([syn].[name]) [object],
            [syn].[type_desc] [object_type],
            [syn].[is_ms_shipped],
            [syn].[base_object_name]
        FROM [#tmpLinkedServers] [srv]
            INNER JOIN [sys].[synonyms] [syn]
                ON [syn].[base_object_name] LIKE N''%'' + [srv].[linked_server_name] COLLATE DATABASE_DEFAULT + N''%''
            INNER JOIN [sys].[schemas] [s]
                ON [s].[schema_id] = [syn].[schema_id]
)
INSERT INTO [#tmpResults]
    SELECT *
    FROM [results]
    OPTION (RECOMPILE);';

    BEGIN TRY
        EXEC sp_executesql @stmt;
    END TRY
    BEGIN CATCH
        INSERT INTO [#tmpResults] (
            [linked_server_name],
            [database_name],
            [database_state]
        ) SELECT [linked_server_name],
                @db,
                @db_state
            FROM [#tmpLinkedServers]
            OPTION (RECOMPILE);
    END CATCH;

    FETCH NEXT FROM [db_crsr] INTO @db, @db_state;
END;

CLOSE [db_crsr];
DEALLOCATE [db_crsr];
GO

IF EXISTS (
    SELECT *
        FROM [#tmpResults]
        WHERE [database_state] <> N'ONLINE'
) SELECT 'Databases were found that are not in ONLINE status. It is not possible to determine whether linked servers are being used.' [Warning]
    OPTION (RECOMPILE);
GO

SELECT [ls].[linked_server_name],
        COUNT(DISTINCT [r].[object]) [potential_object_count]
    FROM [#tmpLinkedServers] [ls]
        LEFT JOIN [#tmpResults] [r]
            ON [ls].[linked_server_name] = [r].[linked_server_name]
    GROUP BY [ls].[linked_server_name]
    ORDER BY [potential_object_count] DESC, [ls].[linked_server_name]
    OPTION (RECOMPILE);
GO

SELECT @@SERVERNAME [server],
        [ls].*,
        [r].[database_name],
        [r].[database_state],
        [r].[object],
        [r].[object_type],
        [r].[is_ms_shipped],
        CASE
            WHEN UPPER([r].[definition]) LIKE N'%OPENQUERY%' THEN 1
            ELSE 0
        END [definition_contains_OPENQUERY],
        CASE [r].[object_type]
            WHEN N'SYNONYM' THEN [r].[definition]
            ELSE N'[...] '
                + SUBSTRING([r].[definition], CHARINDEX([ls].[linked_server_name], [r].[definition]) - 30, LEN([ls].[linked_server_name]) + 60)
                + N' [...]'
        END [1st_occurence],
        [r].[definition]
    FROM [#tmpLinkedServers] [ls]
        LEFT JOIN [#tmpResults] [r]
            ON [ls].[linked_server_name] = [r].[linked_server_name]
    ORDER BY [ls].[linked_server_name], [r].[database_name], [r].[object]
    OPTION (RECOMPILE);
GO

/* Housekeeping */
IF OBJECT_ID(N'tempdb..#tmpLinkedServers') IS NOT NULL
    DROP TABLE [#tmpLinkedServers];

IF OBJECT_ID(N'tempdb..#tmpResults') IS NOT NULL
    DROP TABLE [#tmpResults];
GO