/*
    fix_page_verify_option.sql

    This script reports databases with PAGE_VERIFY property set to other than CHECKSUM
    and generates a SQL query to fix this issue.

    The checksum for the data pages won't be calculated immediately or automatically.
    To do this, all objects/indexes must be rebuild after you have set this option to CHECKSUM.

    Parameter(s) to set or changes to make in advance:

        None.

    Changelog
    ---------
    
    2024-02-27  KMP Initial release.
    
    Known Issues
    ------------

    None.

    The MIT License
    ---------------

    Copyright (c) 2024-2026, Kai-Micael Preiﬂ.

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
        , [page_verify_option]
        , [page_verify_option_desc]
        , N'ALTER DATABASE ' + QUOTENAME([name]) + ' SET PAGE_VERIFY CHECKSUM WITH NO_WAIT;' AS [fix]
    FROM [master].[sys].[databases]
    WHERE [page_verify_option] <> 2
    OPTION (RECOMPILE);