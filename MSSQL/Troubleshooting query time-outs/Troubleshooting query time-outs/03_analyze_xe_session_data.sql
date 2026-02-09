/*
    03_analyze_xe_session_data.sql

    This script returns the recorded data of the XE session.

    The script is part of the SSMS solution "Troubleshooting query time-outs".
    
    Parameter(s) to set or changes to make in advance:

        @xe_file_pattern - Pattern for the XE session target file.

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

DECLARE @xe_file_pattern NVARCHAR(512) = NULL;

/* If the XE session is stopped, you must specify the pattern manually (uncomment and set the appropriate path). */
-- SET @xe_file_pattern = N'<VOL>:\<PATH>\<TO>\<TARGETFILE>\query_time-outs*.xel';

IF NOT EXISTS (
    SELECT *
        FROM [sys].[dm_xe_sessions]
        WHERE [name] = N'query_time-outs'
) AND @xe_file_pattern IS NULL
BEGIN
    RAISERROR (N'XE session seems to be in STOPPED state. You need to set the target file name manually. Alternatively start the session.', 16, 1);
    GOTO FINALLY;
END;

IF @xe_file_pattern IS NULL
BEGIN
/* XE session must be running! */
    ;WITH [evt_file] ([xml]) AS (
        SELECT CAST([xet].[target_data] AS XML)
            FROM [sys].[dm_xe_session_targets] AS [xet]
                INNER JOIN [sys].[dm_xe_sessions] AS [xe]
                    ON [xe].[address] = [xet].[event_session_address]
            WHERE [xe].[name] = N'query_time-outs'
                AND [xet].[target_name] = N'event_file'
    ) SELECT TOP 1 @xe_file_pattern = [n].value('(File/@name)[1]', 'NVARCHAR(512)')
        FROM [evt_file]
            CROSS APPLY [evt_file].[xml].nodes('EventFileTarget') AS [metadata]([n]);

    SET @xe_file_pattern = LEFT(@xe_file_pattern, CHARINDEX(N'query_time-outs', @xe_file_pattern) - 1) + N'query_time-outs*.xel';
END;

SELECT @xe_file_pattern [target_file_pattern];

/* Get the data from all files found. */
;WITH [raw_xml] ([event_data]) AS (
    SELECT CONVERT(XML, [event_data])
        FROM [sys].[fn_xe_file_target_read_file] (@xe_file_pattern, NULL, NULL, NULL)
)
SELECT [n].value('(@name)[1]', 'VARCHAR(50)') AS [event_name],
        [n].value('(@timestamp)[1]', 'DATETIME2') AS [utc_timestamp],
        [n].value('(action[@name="client_hostname"]/value)[1]', 'NVARCHAR(128)') AS [client_hostname],
        [n].value('(action[@name="client_app_name"]/value)[1]', 'NVARCHAR(128)') AS [client_app_name],
        [n].value('(action[@name="session_id"]/value)[1]', 'INT') AS [session_id],
        [n].value('(action[@name="session_server_principal_name"]/value)[1]', 'NVARCHAR(MAX)') AS [session_server_principal_name],
        [n].value('(action[@name="server_principal_name"]/value)[1]', 'NVARCHAR(MAX)') AS [server_principal_name],
        [n].value('(action[@name="username"]/value)[1]', 'NVARCHAR(MAX)') AS [username],
        [n].value('(data[@name="result"]/text)[1]', 'VARCHAR(15)') AS [result],
        [n].value('(action[@name="database_name"]/value)[1]', 'NVARCHAR(128)') AS [database_name],
        [n].value('(data[@name="duration"]/value)[1]', 'INT') AS [duration],
        [n].value('(data[@name="batch_text"]/value)[1]', 'NVARCHAR(MAX)') AS [batch_text],
        [n].value('(data[@name="cpu_time"]/value)[1]', 'INT') AS [cpu],
        [n].value('(data[@name="physical_reads"]/value)[1]', 'INT') AS [physical_reads],
        [n].value('(data[@name="logical_reads"]/value)[1]', 'INT') AS [logical_reads],
        [n].value('(data[@name="writes"]/value)[1]', 'INT') AS [writes],
        [n].value('(data[@name="spills"]/value)[1]', 'INT') AS [spills],
        [n].value('(data[@name="row_count"]/value)[1]', 'INT') AS [row_count]
    FROM [raw_xml]
        CROSS APPLY [raw_xml].[event_data].nodes('event') AS [ed]([n]);

FINALLY:

GO
