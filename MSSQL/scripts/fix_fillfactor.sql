/*
    fix_fillfactor.sql

    This script searches for indexes with fillfactor < 80%
    and generates a SQL query to fix these.

    Parameter(s) to set or changes to make in advance:

        None.

    Changelog
    ---------
    
    2023-03-23  KMP Initial release.
    
    Known Issues
    ------------

    None.

    The MIT License
    ---------------

    Copyright (c) 2023-2024 Kai-Micael Preiß.

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
    [schema] SYSNAME NOT NULL,
    [object] SYSNAME NOT NULL,
    [index] SYSNAME NOT NULL,
    [fill_factor] TINYINT NOT NULL,
    [fix] NVARCHAR(4000) NULL
);

EXEC sp_MSforeachdb N'
USE [?];
SET NOCOUNT ON;

INSERT INTO [#tmpResults]
    SELECT DB_NAME() [database],
            [s].[name] [schema],
            [o].[name] [object],
            [i].[name] [index],
            [i].[fill_factor],
            N''ALTER INDEX ''
                + QUOTENAME([i].[name]) + N'' ON ''
                + QUOTENAME(DB_NAME()) + N''.'' + QUOTENAME([s].[name]) + N''.'' + QUOTENAME([o].[name])
                + N'' REBUILD WITH (FILLFACTOR = 100, ONLINE = ON);'' [fix]
        FROM [sys].[indexes] [i]
            INNER JOIN [sys].[objects] [o]
                ON [i].[object_id] = [o].[object_id]
            INNER JOIN [sys].[schemas] [s]
                ON [o].[schema_id] = [s].[schema_id]
        WHERE [i].[fill_factor] < 80
            AND [i].[fill_factor] <> 0
            AND [i].[is_disabled] = 0
            AND [i].[is_hypothetical] = 0;
';

SELECT *
    FROM [#tmpResults];

DROP TABLE [#tmpResults];
