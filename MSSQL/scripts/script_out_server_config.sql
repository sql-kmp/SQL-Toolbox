/*
    script_out_server_config.sql

    This script creates a SQL script of the SQL Server instance level configurations, e.g. for migrations.

    Parameter(s) to be set in advance: None.

    Changelog
    ---------
    
    2022-09-16  KMP Check for currently inactive settings added.
                    Conversion to XML moved into a separate column.
                    Correct quotations added.
                    Annotation in Known Issues added.
    2022-09-06  KMP Initial release.
    
    Known Issues
    ------------

    Line breaks in grid results won't be retained on copy or save by default in current SSMS versions.

    You have to enable this option explicitly in SSMS here:
        Tools - Options - Query Results - Results to Grid: Retain CR/LF on copy or save

    The MIT License
    ---------------

    Copyright (c) 2022 Kai-Micael Preiß.

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

DECLARE @CRLF NCHAR(2) = NCHAR(13) + NCHAR(10);
DECLARE @inactive_configuration_count SMALLINT = 0;
DECLARE @sql NVARCHAR(MAX) = N'EXEC [sys].[sp_configure] ''show advanced options'', ''1'';
RECONFIGURE;
GO
' + @CRLF;

SELECT @sql = @sql + N'EXEC [sys].[sp_configure] ''' + [name] + N''', ''' + CONVERT(NVARCHAR(50), [value]) + ''';'
        + CASE WHEN ( [name] <> N'min server memory (MB)' AND [value] <> [value_in_use] )
                OR ( [name] = N'min server memory (MB)'    AND [value] = 0    AND [value_in_use] NOT IN (8, 16) )
            THEN NCHAR(9) + N'/* WARNING: Configuration value currently inactive! [value_in_use] = ' + CONVERT(NVARCHAR(20), [value_in_use]) + ' */'
            ELSE N''
        END + @CRLF
    FROM [master].[sys].[configurations]
    WHERE 1 = 1
        -- AND NOT EXISTS ( SELECT [value] INTERSECT SELECT [value_in_use] )    /* skip inactive values */
        AND [name] != N'show advanced options';

SET @sql = @sql + N'RECONFIGURE;
GO

EXEC [sys].[sp_configure] ''show advanced options'', ''1'';
RECONFIGURE;
GO';

SELECT @inactive_configuration_count = COUNT(*)
    FROM [master].[sys].[configurations]
    WHERE (
            [name] <> N'min server memory (MB)'
                AND [name] <> N'show advanced options'
                AND [value] <> [value_in_use]
        ) OR (
            [name] = N'min server memory (MB)'
                AND [value] = 0
                AND [value_in_use] NOT IN (8, 16)
        )
    OPTION (RECOMPILE);

SELECT @sql AS [script],
    CONVERT(XML, N'<!--' + @CRLF + @sql + @CRLF + N'-->') [script_xml],
    CASE
        WHEN @inactive_configuration_count > 0 THEN CONVERT(NVARCHAR(10), @inactive_configuration_count) + N' configuration(s) currently inactive!'
        ELSE NULL
    END [warning],
    N'Change of static configurations require a SQL Server restart to take effect.' [annotation]
OPTION (RECOMPILE);
