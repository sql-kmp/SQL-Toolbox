/*
    checkcatalog.sql

    This script executes dbcc checkcatalog() for all databases.

    You can redirect the results to a file and then evaluate them with awk, e.g.:

    isql -w999 -S? -i checkcatalog.sql -U? -P? >~/checkcatalog.$(date +"%Y%m%d")
    awk '/Checking/ {dbname=$2} /Msg [0-9]+/ {
        msg=$0
        getline
        server=$2
        getline
        print server, dbname, msg, $0
    }' checkcatalog.* | sort | uniq

    Parameter(s) to be set in advance:

        None.

    Changelog
    ---------
    
    2026-01-30  KMP Initial release.

    Known Issues
    ------------

    None so far.

    The MIT License
    ---------------

    Copyright (c) 2026, Kai-Micael Preiß.

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
use master
go

set nocount on
set statistics time, io off
set quoted_identifier on
go

if object_id('##results') is not null
begin
    drop table ##results
end
go

create table ##results (
    "dbid" int,
    "database_name" sysname(30),
    "error_nr" int
)
go

declare DB_CURSOR cursor for
    select "name"
        from master..sysdatabases
        where "name" not in ( 'tempdb' )
            and "status" & 32 != 32     /* exclude databases created with for load option */
            and "status3" & 256 != 256  /* exclude user-created tempdbs */
            and "status2" & 16 != 16    /* exclude offline databases */
            and "status2" & 32 != 32    /* exclude databases in state offline until recovery completes */
    for read only
go

open DB_CURSOR
go

declare @dbname varchar(128)

fetch DB_CURSOR into @dbname

while @@fetch_status = 0
begin
    dbcc checkcatalog(@dbname)
    insert into ##results ( "dbid", "database_name", "error_nr")
        select DB_ID(@dbname), @dbname, @@error
    fetch DB_CURSOR into @dbname
end
go

close DB_CURSOR
deallocate DB_CURSOR
go

select *
    from ##results
go

if object_id('##results') is not null
begin
    drop table ##results
end
go