/*
    01_create_xe_session.sql

    This script creates the extended events session to capture aborted batches.

    The script is part of the SSMS solution "Troubleshooting query time-outs".

    sqlserver.server_principal_name, sqlserver.session_server_principal_name,
    and sqlserver.username can differ (execution within another context). Hence,
    all of them are captured.
    
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

CREATE EVENT SESSION [query_time-outs] ON SERVER
    ADD EVENT sqlserver.rpc_completed (
        ACTION (
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_name,
            sqlserver.server_principal_name,
            sqlserver.session_id,
            sqlserver.session_server_principal_name,
            sqlserver.sql_text,
            sqlserver.username
        ) WHERE (
            [package0].[equal_uint64]( [result],'Abort' )
        )
    ), ADD EVENT sqlserver.sql_batch_completed (
        SET collect_batch_text = (1)
        ACTION (
            sqlserver.client_app_name,
            sqlserver.client_hostname,
            sqlserver.database_name,
            sqlserver.server_principal_name,
            sqlserver.session_id,
            sqlserver.session_server_principal_name,
            sqlserver.sql_text,
            sqlserver.username
        ) WHERE (
            [package0].[equal_uint64]( [result],'Abort' )
        )
    ) ADD TARGET package0.event_file (
        SET filename = N'query_time-outs',
            max_file_size = (128)
    ) WITH (
        MAX_MEMORY = 4096 KB,
        EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
        MAX_DISPATCH_LATENCY = 30 SECONDS,
        MAX_EVENT_SIZE = 0 KB,
        MEMORY_PARTITION_MODE = NONE,
        TRACK_CAUSALITY = OFF,
        STARTUP_STATE = ON
    );
GO
