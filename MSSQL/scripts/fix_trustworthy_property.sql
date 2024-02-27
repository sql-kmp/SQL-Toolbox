/*
    fix_trustworthy_property.sql

    This script reports databases with TRUSTWORTHY property set to ON and generates
    a SQL query to fix this issue.

    There are certain threats when TRUSTWORTHY is set to ON. It is therefore recommended
    to switch it off.

    Parameter(s) to set or changes to make in advance:

        None.

    Changelog
    ---------
    
    2024-02-27  KMP Bug fix.
    2023-07-04  KMP Initial release.
    
    Known Issues
    ------------

    None.

    The MIT License
    ---------------

    Copyright (c) 2023-2024 Kai-Micael Preiﬂ.

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
GO

SELECT [name] AS [database]
        , [create_date]
        , SUSER_SNAME([owner_sid]) AS [dbowner]
        , [is_trustworthy_on]
        , N'ALTER DATABASE ' + QUOTENAME([name]) + ' SET TRUSTWORTHY OFF;' AS [fix]
    FROM [master].[sys].[databases]
    WHERE [name] <> N'msdb'            /* Microsoft obviously couldn't solve it better ... */ 
        AND [is_trustworthy_on] = 1
    OPTION (RECOMPILE);
