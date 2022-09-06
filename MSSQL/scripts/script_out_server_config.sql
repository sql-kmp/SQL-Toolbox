/*
	script_out_server_config.sql

	This script creates a SQL script of configuration at SQL Server instance level, e.g. for migrations.

	Parameter(s) to be set in advance: None.

	Changelog
	---------
	
	2022-09-06	KMP	Initial release.
	
	Known Issues
	------------

	None.

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

DECLARE @sql NVARCHAR(MAX) = N'EXEC sp_configure N''show advanced options'', 1;
RECONFIGURE;
GO
' + NCHAR(13) + NCHAR(10);

SELECT @sql = @sql + N'EXEC sp_configure ''' + [name] + N''', ' + CONVERT(NVARCHAR(50), [value]) + ';' + NCHAR(13) + NCHAR(10)
	FROM [sys].[configurations]
	WHERE 1 = 1
		-- AND NOT EXISTS ( SELECT [value] INTERSECT SELECT [value_in_use] )	/* skip inactive values */
		AND [name] != N'show advanced options';

SET @sql = @sql + N'RECONFIGURE;
GO

EXEC sp_configure N''show advanced options'', 1;
RECONFIGURE;
GO';

SELECT CONVERT(XML, @sql) AS [sqlcmd];
