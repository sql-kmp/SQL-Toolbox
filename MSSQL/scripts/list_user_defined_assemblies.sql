/*
    list_user_defined_assemblies.sql

    This script lists all user-defined assemblies.

    Parameter(s) to set or changes to make in advance:

        None.

    Changelog
    ---------
    
    2023-07-04  KMP Initial release.
    
    Known Issues
    ------------

    None.

    The MIT License
    ---------------

    Copyright (c) 2023-2026, Kai-Micael Preiﬂ.

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
    [assembly_name] SYSNAME NOT NULL,
    [permission_set_desc] NVARCHAR(120) NULL,
    [create_date] DATETIME NOT NULL,
    [modify_date] DATETIME NOT NULL,
    [is_user_defined] BIT NULL
);

EXEC sp_MSforeachdb N'
USE [?];

SET NOCOUNT ON;

INSERT INTO [#tmpResults]
SELECT DB_NAME() AS [database]
        , [name] AS [assembly_name]
        , [permission_set_desc]
        , [create_date]
        , [modify_date]
        , [is_user_defined]
    FROM [sys].[assemblies]
    WHERE [is_user_defined] = 1
    OPTION (RECOMPILE);
';

SELECT *
    FROM [#tmpResults]
    ORDER BY [database], [assembly_name]
    OPTION (RECOMPILE);

DROP TABLE [#tmpResults];
