/*
    04_stop_xe_session.sql

    This script simply stops the extended event session.
	
	The script is part of the SSMS solution "Troubleshooting query time-outs".
    
    Parameter(s) to set or changes to make in advance:

        None.

    Changelog
    ---------
    
    2024-02-01  KMP Initial release.

    Known Issues
    ------------

        - Session name is static.

    The MIT License
    ---------------

    Copyright (c) 2024 Kai-Micael Preiﬂ.

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

IF EXISTS (
    SELECT *
        FROM [sys].[dm_xe_sessions]
        WHERE [name] = N'query_time-outs'
)
BEGIN
    ALTER EVENT SESSION [query_time-outs] ON SERVER STATE = STOP;
END;
GO
