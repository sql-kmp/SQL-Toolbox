/*
    ase_zombies.sql

    Using this script you can identify zombie processes in SAP ASE.

    Parameter(s) to be set in advance:

        None.

    Changelog
    ---------

    2023-07-03  KMP Initial release.

    Known Issues
    ------------

    None so far.

    The MIT License
    ---------------

    Copyright (c) 2023-2026, Kai-Micael Preiß.

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

/*
    long running transaction showing up in systransactions/syslogshold/syslocks
    but not in sysprocesses:
*/

select *
    from systransactions
    where spid not in ( select spid from sysprocesses )

select *
    from syslogshold
    where spid not in ( select spid from sysprocesses )

select *
    from syslocks
    where spid not in ( select spid from sysprocesses )

/* or long running tranasction ... */
select *
    from syslogshold -- note spid

/* ... with no IO/CPU movement (take "snapshots" and calculate diffs) ... */

select *
    from master..sysprocesses
    where spid = <SPID>

/* ... and no locks for the spid: */

select *
    from syslocks
    where spid = <SPID>