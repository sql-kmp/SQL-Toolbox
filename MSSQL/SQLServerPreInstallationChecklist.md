# SQL Server pre-installation checklist

The following list does not claim to be complete. It mainly consists of checks that I have had to perform regularly for customers when setting up new SQL Server instances (on-premises).

The pre-checks are based on best practice recommendations for SQL Server. These recommendations are sometimes discussed very controversially. Furthermore, it may be true that some of them only make limited sense today.

If you have made (negative or different) experiences related to individual items, please feel free to share these in a comment. I would be happy to include them in the list as a relativizing addition, if applicable.

**Helpful** and **constructive** hints are always welcome!

Having this said, let's start with the list.

Configuration of a VM is out of scope here. You can find more information here:
- [Tips for configuring Microsoft SQL Server in a virtual machine (1002951)](https://kb.vmware.com/s/article/1002951)
- [ARCHITECTING MICROSOFT SQL SERVER ON VMWARE VSPHERE® - Best Practices Guide](https://www.vmware.com/content/dam/digitalmarketing/vmware/en/pdf/solutions/sql-server-on-vmware-best-practices-guide.pdf)
- [Successfully Virtualizing Microsoft SQL Server for High Availability on Azure VMware Solutions - BEST PRACTICES GUIDE](https://www.vmware.com/content/dam/digitalmarketing/vmware/en/pdf/docs/vmw-ms-sql-server-workloads-on-avs.pdf)
- [Best Practices for SQL Server on VMware - Distilled](https://www.nocentino.com/posts/2021-09-27-sqlserver-vms-best-practices/)
- [VMware and SQL Server Best Practices](https://straightpathsql.com/archives/2020/12/vmware-and-sql-server-best-practices/)

Starting point should be a fully patched operating system. Ideally, the operating system should be installed in English.

⚠ The hardware clock should always be set to **UTC**. Period! If you do not agree, please read this: [The Worst Server Setup Mistake You Can Make](http://yellerapp.com/posts/2015-01-12-the-worst-server-setup-you-can-make.html)

- [ ] OS's power plan setting:

  ```
  POWERCFG /GETACTIVESCHEME
  ```

  You want to see *"High performance"* in the result. Don't forget to check BIOS' power plan settings.

- [ ] Port shares (see also [Configure the Windows Firewall to Allow SQL Server Access](https://docs.microsoft.com/en-us/sql/sql-server/install/configure-the-windows-firewall-to-allow-sql-server-access)):

  | Port        | Usage                                                        |
  | ----------- | ------------------------------------------------------------ |
  | TCP 1433    | default SQL Server instance (database engine)[^1]            |
  | TCP 1434    | Dedicated Admin Connection (default instance)[^2]            |
  | UDP 1434    | SQL Server Browser, which is often disabled due to the customer's security policy |
  | TCP/UDP 389 | Authentication (Windows authentication)                      |

  [^1]:Named instances use dynamic ports, if not configured otherwise in the SQL Server Configuration Manager.
  [^2]:The port differs for named instances. It'll show up in the error log. You can configure a fixed port in the registry.

  PowerShell example (administrative prompt):

  ```powershell
  New-NetFirewallRule -DisplayName "SQLServer default instance" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow
  ```

  You'll need additional ports if you are working in a clustered environment (Windows Server Failover Cluster, which is a requirement for AlwaysOn features).

- [ ] NTFS cluster size (administrative command prompt):

  ```
  fsutil fsinfo ntfsinfo [drive]
  ```

  | Files                             | recommended cluster size                                     |
  | --------------------------------- | ------------------------------------------------------------ |
  | Binaries (C:)[^3]                 | 4k = default cluster size (informational)                    |
  | data files (user databases)       | 64k, 1MB respectively                                        |
  | database log files (incl. tempdb) | 8k, 64k respectively                                         |
  | data files (tempdb)               | 64k, 1MB respectively (on dedicated fast storage)            |
  | backups                           | 64k, 1MB respectively                                        |
  | (error) log files[^4]             | 4k = default cluster size                                    |
  | instance root w/ system databases | 4k should be ok, usually error log and trace files are stored in this directory structure |

  [^3]:at least 128 GB of space nowadays (i.e. 2021 currently)
  [^4]:Sometimes it's a good idea to store the error log and trace files on a separate volume.

- [ ] disable compression:

  - Use `gpedit.msc` ...

    ```
    Computer Configuration
      ↳ Administrative Templates
        ↳ System
          ↳ Filesystem
            ↳ NTFS → Do not allow compression on all NTFS volumes: Enabled
    ```

  - ... or disable it directly (administrative command prompt):

    ```
    fsutil behavior set DisableCompression 0
    ```

- [ ] If necessary, set up a grouped Managed Service Account (gMSA):

  - [ ] RSAT feature required:

    ```powershell
    # check installation status:
    Get-WindowsFeature RSAT-AD-PowerShell
    # if not installed yet:
    Add-WindowsFeature -Name "RSAT-AD-PowerShell" –IncludeAllSubFeature
    ```

  - [ ] KDS Rootkey (domain admin privileges required):

    ```powershell
    # check whether there is already one:
    Get-KdsRootKey
    # if not:
    Add-KdsRootKey -EffectiveImmediately
    ```

    > Using Add-KdsRootKey  -EffectiveImmediately will add a root key to the target DC which will be used by the KDS service immediately. However, other domain controllers  will not be able to use the root key until replication is successful.
    > (source: [Create the Key Distribution Services KDS Root Key](https://docs.microsoft.com/en-us/windows-server/security/group-managed-service-accounts/create-the-key-distribution-services-kds-root-key))

  - [ ] Create the (grouped) Managed Service Account (domain admin privileges required):

    ```powershell
    New-ADServiceAccount -Name <gMSA> -DNSHostName <gMSA>.<domain> -PrincipalsAllowedToRetrieveManaged
    Password "<host1$>,<host2$>,<...>,<hostN>"
    # configure gMSA account (on each member server)
    Install-ADServiceAccount <gMSA>
    # validate gMSA account (on each member server) -> should return True 
    Test-ADServiceAccount <gMSA>
    ```

    ⚠The gMSA does not need to be a local administrator. Setup will automatically grant least privileges required.

- [ ] Design backup strategy related to RPO and RTO.

- [ ] Finally, have the correct installation media (version, edition) and patches at hand. The English version is very much appreciated by me 😉.

