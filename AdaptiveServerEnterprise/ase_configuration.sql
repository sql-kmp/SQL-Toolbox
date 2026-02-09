/*
    ase_configuration.sql

    This script returns the current instance level configuration. The script is
    especially useful for comparisons between different instances (groupings in
    sp_configure output can be very confusing with different versions).

    Parameter(s) to be set in advance:

        None.

    Changelog
    ---------

    2022-10-10  KMP Initial release.

    Known Issues
    ------------

    None.

    The MIT License
    ---------------

    Copyright (c) 2022-2026, Kai-Micael Preiß.

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

select "servername" = @@servername,
    sc.name,
    scc.value,
    scc.value2,
    scc.defvalue
from master.dbo.sysconfigures sc, master.dbo.syscurconfigs scc
where sc.config *= scc.config
    and sc.parent != 19 /* caches */
    and sc.config > 100 /* exclude group names */
order by sc.name
go