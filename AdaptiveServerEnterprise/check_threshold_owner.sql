/*
    check_threshold_owner.sql

    This script returns all thresholds (from systhresholds) having an owner other than sa.

    Fix/mitigation:

        1. Log in with the dbowner's login,
        2. switch to the respective database (USE ?) and
        3. execute the generated statement.

    Parameter(s) to be set in advance:

        None.

    Changelog
    ---------

    2023-08-23  KMP Bugfix.
    2023-04-03  KMP Initial release.

    Known Issues
    ------------

    None so far.

    The MIT License
    ---------------

    Copyright (c) 2023 Kai-Micael Preiß.

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
go

declare DB_CURSOR cursor for
    select name
        from master..sysdatabases
    for read only
go

open DB_CURSOR
go

create table ##results (
    dbid int,
    database_name sysname(30),
    dbowner sysname(30),
    segment smallint,
    free_space unsigned int,
    status smallint,
    suid int,
    user_name sysname(30) null,     /* allow NULL values, if suser_name() returns NULL */
    proc_name varchar(255)
)

declare @dbname varchar(128)

fetch DB_CURSOR into @dbname

while @@fetch_status = 0
begin
    declare @sql varchar(1000)
    set @sql = 'declare @owner_suid int

select @owner_suid = suid
    from master..sysdatabases
    where name = ''' +  @dbname + '''

insert into ##results
select "dbid" = db_id(''' + @dbname + '''),
        "database_name" = ''' + @dbname + ''',
        "dbowner" = suser_name(@owner_suid),
        segment,
        free_space,
        status,
        suid,
        "user" = suser_name(suid),
        proc_name
    from ' + @dbname + '..systhresholds
    where suid <> @owner_suid
'
    execute (@sql)
    fetch DB_CURSOR into @dbname
end
go

close DB_CURSOR
deallocate DB_CURSOR
go

select instance = @@servername,
    r.database_name,
    r.dbowner,
    "readonly" = case (d.status & 1024)
        when 1024 then 1
        else 0
    end,
    r.segment,
    r.free_space,
    r.status,
    r.suid,
    r.user_name,
    mitigation = 'exec sp_modifythreshold "' + database_name + '", '
        + ( select name from syssegments seg where seg.segment = r.segment )
        + ', ' + cast(free_space as varchar(10)),
    r.proc_name
from ##results as r
    inner join master..sysdatabases as d
        on r.dbid = d.dbid

drop table ##results
go

set nocount off
go
