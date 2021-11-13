/*
    quick_health_check.sql

    This script does a quick health check. The following result sets are returned:
        - data and log usage
        - last dbcc results
        - last dbcc checks
        - some performance counters (20 seconds sample)
        - long running transactions
        - infected processes
        - monErrorLog (filtered)

    Parameter(s) to be set in advance: none.

    Changelog
    ---------

    2021-11-13  KMP Initial release.

    Known Issues
    ------------

    - The dbccdb database must exist. If it is missing, an error is returned for the corresponding queries.

    The MIT License
    ---------------

    Copyright (c) 2021 Kai-Micael Preiß.

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

/*  1 - LOG & DATA Used Space (% + MB) for all databases    */

select @@servername AS "server", *
from (
    select d.dbid,
        db_name(d.dbid) as "database",
        cast(sum(case when u.segmap & 3 > 0 then cast(u.size as bigint) * @@maxpagesize / 1048576.0 else 0.0 end) as decimal(10,1)) as "Data Size (MB)",
        cast(sum(case when u.segmap & 3 > 0 then cast(u.size as bigint) - cast(curunreservedpgs(u.dbid, u.lstart, u.unreservedpgs) as bigint) else 0.0 end) * @@maxpagesize / 1048576.0 as decimal(10,2)) as "Used Data (MB)",
        cast(100.0 - 100.0 * cast(sum(case when u.segmap & 3 > 0 then curunreservedpgs(u.dbid, u.lstart, u.unreservedpgs) else 0.0 end) / sum(case when u.segmap & 3 > 0 then u.size ELSE 0.0 end) as decimal(10,5)) as decimal(3,1)) as "data_full",
        cast(sum(case when u.segmap & 4 = 4 then cast(u.size as bigint) * @@maxpagesize / 1048576.0 else 0.0 end) as decimal(10,1)) as "Log Size (MB)",
        cast(cast(lct_admin("logsegment_freepages", d.dbid) as bigint) * @@maxpagesize / 1048576.0 as decimal(10,1)) as "Free Log (MB)",
        cast(100.0 - 100.0 * cast(lct_admin("logsegment_freepages", d.dbid) as bigint) / sum(case when u.segmap & 4 = 4 then cast(u.size as bigint) else 0.0 end) as decimal(3,1)) as "log_full"
    from master..sysdatabases d, master..sysusages u
    where u.dbid = d.dbid
        and d.dbid != 3         -- without model databases
        and d.status != 256     -- no suspect databases
    group by d.dbid
) as usage
order by case when data_full > log_full then data_full else log_full end desc

/*  2 - last DBCC checks    */

select @@servername as "server",
    db.name AS "database",
    cte.opid,
    cte.optype,
    cte.suid,
    suser_name(cte.suid) as "username",
    cte.start,
    cte.finish,
    datediff(day, cte.start, getdate()) as age
from master..sysdatabases db
    left outer join (
        select o.*
        from dbccdb..dbcc_operation_log as o
        where opid = ( select max(opid) from dbccdb..dbcc_operation_log where dbid = o.dbid )
            and optype = 3
    ) cte on db.dbid = cte.dbid
where db.name not like '%tempdb%'
order by "age" desc, "database"

/*  3 - DBCC Checks: number of hard faults  */

create table #dbcc_runs (
    dbid   smallint not null,
    opid smallint not null 
)

insert into #dbcc_runs
select dbid, max(opid)
from dbccdb..dbcc_operation_log 
group by dbid  

select @@servername as "server",
    count(*) as "sum_hardfaulty_dbs",
    sum(s.intvalue) as "#sum_faults"
from dbccdb..dbcc_operation_results s, #dbcc_runs t
where s.dbid = t.dbid
    and s.opid = t.opid 
    and s.optype = 3            -- verified results only (checkverify)
    and s.type_code in (1000)   -- only hard faults
    and s.intvalue > 0

/*  4 - DBCC Checks: display details AND recommendations    */

select @@servername as "server",
    db_name(s.dbid) as "database",
    sum(s.intvalue) as "#faults",
    case s.type_code
        when 1000 then "hard faults"
        when 1001 then "soft faults"
        when 1002 then "check aborted"
    end as "type_code",
    s.opid
from dbccdb..dbcc_operation_results s, #dbcc_runs t
where s.dbid = t.dbid
    and s.opid = t.opid
    and s.optype = 3                        -- verified results only (checkverify)
    and s.type_code in (1000, 1001, 1002)   -- hard, soft and abort results
    and s.intvalue > 0
group by s.dbid, s.opid, s.type_code

select @@servername as "server",
    faults.*,
    dte.type_name as "error",
    dt.description
from (
        select db_name(df.dbid) as "database",
            object_name(df.id, df.dbid) as "object",
            index_name(df.dbid, df.id, df.indid) as "index",
            df.type_code AS "error_code"
        from dbccdb..dbcc_faults df, #dbcc_runs dr
        where df.status in (1, 2, 3)            -- 1 hard faults, 2 soft faults, 3 soft fault upgraded to hard fault
            and df.opid = dr.opid
            and df.dbid = dr.dbid
        group by df.dbid, df.opid, df.type_code, df.id, df.indid
    ) AS faults,
    dbccdb..dbcc_reco dre,
    dbccdb..dbcc_types dt,
    dbccdb..dbcc_types dte
where faults.error_code = dre.fault_type
    and dt.type_code = dre.reco_type
    and faults.error_code = dte.type_code
order by "database", "object", "index", "error_code"

drop table #dbcc_runs

/*  5 - Performance KPIs    */

declare @tran1 int
declare @tran2 int
declare @req1 int           -- Requests/Sec - Anzahl der Requests im ProcedureCache
declare @req2 int
declare @conns int
declare @achr numeric(4, 2) -- All Cache Hit Ratio: Averaging Ratio over Ratio of every single cache
declare @pchr numeric(5, 2) -- Procedure Cache Hit Ratio

declare @var char(20)
select @var = "00:00:20"

select @tran1 = sum(Transactions)
from master..monState

select @req1 = Requests
from master..monProcedureCache

waitfor delay @var 

select @tran2 = sum(Transactions), @conns = Connections
from master..monState

select @req2 = Requests
from master..monProcedureCache

select @achr = convert(numeric(4,2), avg(convert(numeric(4,1), 100 - ((convert(numeric(12,2),PhysicalReads) / convert(numeric(12,2),CacheSearches))*100))))
from master..monDataCache
where CacheSearches > 0

select @pchr = convert(numeric(5,2),(100 - (100 * ((1.0 * Loads) / Requests))))
from master..monProcedureCache

select @@servername as "server",
    convert(numeric(7,2), (@tran2 - @tran1) / 20.0) as "Transactions/sec",
    convert(numeric(5,2), (@req2 - @req1) / 20.0) as "Requests/sec (Procs Requests in ProcCache)",
    @conns as "Active Connections",
    @achr AS "All Cache Hit Ratio (%)",
    @pchr AS "Procedure Cache Hit Ratio"

/*  6 - Check for long running transctions  */

declare @transAge int, @c int

set @transAge = -1      -- duration of transaction (1h)

select @c = count(*)
from master..syslogshold sh 
where sh.starttime <= dateadd(hh,@transAge, getdate())

if @c = 0
begin
    select @@servername as "server", 'none' as "long running XACTs"
end
else
begin
    select @@servername as "server",
        sh.spid,
        sh.starttime,
        db_name(sh.dbid) as "DatabaseName",
        suser_name(mst.ServerUserID) as "SessionUserName",
        mpl.Login,
        datediff(hh, sh.starttime, getdate()) as "TimeRunningHours",
        datediff(mi, sh.starttime, getdate()) as "TimeRunningMinutes",
        mst.SQLText,
        mpl.ClientHost
    from master..monProcessSQLText mst
        inner join master..syslogshold sh on sh.spid = mst.SPID
        inner join master..monProcessLookup mpl on mpl.SPID = sh.spid
    where sh.starttime <= dateadd(hh, @transAge, getdate())
end

/*  7 - Check for infected processes    */

select @c = count(*) 
from master..sysprocesses sp
where sp.status in ('infected', 'latch sleep', 'lock sleep', 'PLC sleep')

if @c = 0
begin
    select @@servername as "server", 'none' as "infected processes"
end
else
begin
    select @@servername as "server", *
    from master..sysprocesses sp
    where sp.status in ('infected', 'latch sleep', 'lock sleep', 'PLC sleep')
end

/*  8 - monErrorLog */

select @@servername as "server",
    InstanceID,
    KPID,
    FamilyID,
    SPID,
    EngineNumber,
    Time,
    ErrorNumber,
    Severity,
    State,
    ErrorMessage
from master..monErrorLog
where ErrorNumber not in (
        110193, 190030, 190031, 190032, 190033, 30070, 190186, 190197
        , 110208, 12560, 12580, 300016, 12554, 12557, 12558, 110296
        , 110081, 5124, 240047, 40077, 40075, 190022, 3479, 190016
        , 190014, 290022, 110313, 190170, 190066, 300211, 120005, 300008
        , 300009, 300160, 3509, 240084, 240089                                  -- ASE startup
        , 3476, 3405, 3408, 3444, 11245, 12562, 12563, 12564, 12565, 12566
        , 12567, 12568, 12571, 12572, 12573, 12574, 12575, 12576, 12586, 12893
        , 240142, 240052, 300247, 9689                                          -- database startup
        , 110299        -- Begin processing to generate RSA keypair.
        , 110300        -- Completed processing to generate RSA keypair.
        , 120191        -- https://launchpad.support.sap.com/#/notes/0002158307
        , 190004        -- https://launchpad.support.sap.com/#/notes/0001997747
        , 300197        -- Beginning REORG RECLAIM_SPACE of '%' partition '%'.
        , 300201        -- REORG RECLAIM_SPACE of '%' partition '%' completed.
        , 300336        -- Beginning REORG REBUILD of index '%' on table '%'.
        , 300337        -- REORG REBUILD of index '%' on table '%' completed.
        , 240059        -- wash size changed due to pool size change
    ) and ErrorMessage not like 'Processed % allocation unit(s) out of % units (allocation page %). % completed%'   -- exclude progress message
order by Time
