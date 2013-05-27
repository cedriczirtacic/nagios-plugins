nagios-plugins
==============

Collection of specific Nagios plugins.

Description
-----------

I will drop here some Nagios plugins that I'd to wrote at work.

Plugins
-------

### check_nortel.sh
Monitor for the Nortel Layer2-3 GbE Switch.
```bash
Usage: ./check_nortel.sh <hostname|ip> <action> (critical|warning)
Actions:
        * ping
        * traffic (w|c)
```

### check_tsm.pl
Plugin for IBM's Tivoli Storage Manager
```bash
Usage:  check_tsm.pl [-d|--options dsmadmc_options][-p|--password] [-u|--username] [-s|--servername]
           [-m|--monitor] -w warning -c critical
```
