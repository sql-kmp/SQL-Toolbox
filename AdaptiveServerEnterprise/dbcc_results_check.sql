/*
    dbcc_result_check.sql

    This script returns the results of the last integrity check for each checked database.

    Parameter(s) to be set in advance:

		@threshold  - Threshold value in days, how long ago the last test may be. If NULL, this filter will be ignored.

    Changelog
	---------

	2021-11-13	KMP	Initial release.

    Known Issues
    ------------

    - The dbccdb database must exist. If it is missing, an error is returned for the corresponding queries.

	The MIT License
	---------------

	Copyright (c) 2021-2022 Kai-Micael Preiß.

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

declare @threshold int      -- check for databases that have not been checked for more than @threshold days
set @threshold = NULL

/*  1 - create temporary table with last opid   */

create table #dbcc_runs (
	dbid smallint not null,
    opid smallint not null 
)

insert into #dbcc_runs
select dbid, max(opid)
from dbccdb..dbcc_operation_log
group by dbid

/*  2 - number of database w/ hard faults   */

select count(*) as "sum_hardfaulty_dbs",
    sum(s.intvalue) as "#sum_faults"
from dbccdb..dbcc_operation_results s, #dbcc_runs t
where s.dbid   = t.dbid
    and s.opid   = t.opid 
    and s.optype = 3            -- verified only (checkverify)
    and s.type_code in (1000)   -- hard faults only
    and s.intvalue > 0

/*  3 - fault count per database    */

select db_name(s.dbid) as "database",
    sum(s.intvalue) as "#faults",
    case s.type_code
        when 1000 then "hard faults"
        when 1001 then "soft faults"
        when 1002 then "check aborted"
    end as "type",
    s.opid
from dbccdb..dbcc_operation_results s, #dbcc_runs t
where s.dbid   = t.dbid
    and s.opid   = t.opid 
    and s.optype = 3                        -- verified only (checkverify)
    and s.type_code in (1000,1001,1002)     -- hard, soft and abort results
    and s.intvalue > 0
group by s.dbid, s.opid, s.type_code

/*  4 - dbcc faults found during last sp_dbcc_runcheck  */

select faults.*,
    dte.type_name as "Fehler",
    dt.description as "Bereinigung"
from (
        select 	db_name(df.dbid) as "Database",
            object_name(df.id, df.dbid) as "DBObject",
            index_name(df.dbid, df.id,df.indid) as "IndexName",
            df.type_code as "Fehlercode"
        from dbccdb..dbcc_faults df, #dbcc_runs dr
        where df.status in (1,2,3)      -- 1 hard faults, 2 soft faults, 3 soft fault upgraded to hard fault
            and df.opid = dr.opid
            and df.dbid = dr.dbid
        group by df.dbid, df.opid, df.type_code, df.id, df.indid
    ) as faults,
    dbccdb..dbcc_reco dre,
    dbccdb..dbcc_types dt,
    dbccdb..dbcc_types dte
where faults.Fehlercode = dre.fault_type
    and dt.type_code = dre.reco_type
    and faults.Fehlercode = dte.type_code
order by 1, 2, 3

drop table #dbcc_runs

/*  5 - databases that have never been checked or have not been checked for longer than specified in @threshold */

select
    @@servername as "srv",
    db.name as "database",
    cte.opid,
    cte.optype,
    cte.suid,
    suser_name(cte.suid) as "username",
    cte.finish,
    datediff(day, cte.start, getdate()) as age
from master..sysdatabases db
    left outer join (
        select o.*
        from dbccdb..dbcc_operation_log as o
        where opid = (select max(opid) from dbccdb..dbcc_operation_log where dbid = o.dbid)
            and optype = 3
    ) cte on db.dbid = cte.dbid
where db.name not like '%tempdb%'
    and (
        datediff(day, cte.start, getdate()) >= COALESCE(@threshold, 0)
            or cte.start is null
    )
order by "age" desc, "database"
