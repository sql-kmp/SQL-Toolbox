/*
    log_cache_tempdb.sql

    Aim of this script is to bind syslogs of the tempdb database to a named cache.

    The story behind that is tempdb tuning. Dedicated log caches usually always improve read performance.

    But wait! You can't bind individual system tables in tempdb, right? That will do the trick:
        - Bind model..syslogs to the named cache.
        - Restart ASE.

    This will rebind tempdb..syslogs every time SAP ASE is restarted (and syslogs in every new database as well).

    Parameter(s) to be set in advance:

        None.

    Changelog
    ---------

    2022-09-28  KMP Initial release.

    Known Issues
    ------------

    - The name of the cache is hard coded. It's assumed that a (log only) cache named log_cache exists.

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

/* database must be in single user mode */
sp_dboption model, 'single user', true
go

use model
go

/* bind syslogs to log_cache assuming that this cache exists */
sp_bindcache log_cache, model, syslogs
go

use master
go

/* back to multi user mode */
sp_dboption model, 'single user', false
go

/* after restarting ASE tempdb..syslogs is binded to log_cache */
