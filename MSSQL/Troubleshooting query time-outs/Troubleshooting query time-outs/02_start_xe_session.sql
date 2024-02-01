/*
    02_start_xe_session.sql

    This script starts the extended event session created in the previous step
    and returns the FQFN of the target file as well as the pattern (in case of
    multiple target files) for the following analysis.
    
    The script is part of the SSMS solution "Troubleshooting query time-outs".
    
    Parameter(s) to set or changes to make in advance:

        None.

    Changelog
    ---------
    
    2024-02-01  KMP Initial release.

    Known Issues
    ------------

        - Session name is static.
        - The script assumes that the name of the target file begins with
          the name of the XE session (see step 1).

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

IF NOT EXISTS (
    SELECT *
        FROM [sys].[server_event_sessions]
        WHERE [name] = N'query_time-outs'
)
BEGIN
    RAISERROR (N'XE session ''%s'' does not exist on this server.', 16, 1, N'query_time-outs');
    GOTO FINALLY;
END;

IF NOT EXISTS (
    SELECT *
        FROM [sys].[dm_xe_sessions]
        WHERE [name] = N'query_time-outs'
)
BEGIN
    ALTER EVENT SESSION [query_time-outs] ON SERVER STATE = START;
END;

DECLARE @xe_file NVARCHAR(512) = NULL,
    @xe_file_pattern NVARCHAR(512) = NULL;

/* XE session must be running! */
;WITH [evt_file] ([xml]) AS (
    SELECT CAST([xet].[target_data] AS XML)
        FROM [sys].[dm_xe_session_targets] AS [xet]
            INNER JOIN [sys].[dm_xe_sessions] AS [xe]
                ON [xe].[address] = [xet].[event_session_address]
        WHERE [xe].[name] = N'query_time-outs'
            AND [xet].[target_name] = N'event_file'
) SELECT TOP 1 @xe_file = [n].value('(File/@name)[1]', 'NVARCHAR(512)')
    FROM [evt_file]
        CROSS APPLY [evt_file].[xml].nodes('EventFileTarget') AS [metadata]([n]);

SET @xe_file_pattern = LEFT(@xe_file, CHARINDEX(N'query_time-outs', @xe_file) - 1) + N'query_time-outs*.xel';

SELECT @xe_file [current_target_file],
    @xe_file_pattern [target_file_pattern];

FINALLY:

GO
