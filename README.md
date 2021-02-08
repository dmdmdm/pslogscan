# pslogscan
A simple log file scanner for the [Postfix](http://www.postfix.org) [Postscreen](http://www.postfix.org/postscreen.8.html) service.
This script gives an overview of how Postscreen is performing. Written for /bin/sh Bourne Shell. 

# This version

Minor improvements [to the fine script](https://archive.mgm51.com/sources/pslogscan.html) by Mike Miller.
Posted on github with permission.

The script required a small amount of configuration by hand at the top.  This update makes it unnecessary to hardcode most of those
options by hand.  It uses the `postconf` command to find the info.
So if you change those options in `/etc/postfix/main.cf` you don't need to update the script.
However, please still read the config section of the script to make sure its ok for you.
Works fine with bash5 on Linux.  Runs very quickly for me.

# Readme from orginal

Initially tested on FreeBSD 8.4 and Postfix 2.11.1. It has run fine on interim versions of FreeBSD and Postfix. Currently running with FreeBSD 12.1 and Postfix 3.5.7.

Read the comments in the script to see what options you may need to tweak.

Sample output, showing Postscreen rejecting about 18% of the incoming mail. Note the postscreen portion of this maillog is about 340MB in size, about 3 million postscreen log records. The results of the time command are shown after the sample output.

```output
Scanning /var/log/maillog
 
  Screening status log records:
                  CONNECT:     705024
                 PASS NEW:      31104
                 PASS OLD:     228096
              WHITELISTED:     316224
              BLACKLISTED:          0
 
                 rejected:     129600  (18%)
 
 
  Protocol error log records:
                   HANGUP:      57024
                 PREGREET:      10368
             BARE NEWLINE:          0
       COMMAND TIME LIMIT:          0
       COMMAND PIPELINING:          0
 
  DNS black list log records:
         zen.spamhaus.org:     160704
           bl.spamcop.net:      51840
   b.barracudacentral.org:      98496
 
  DNSBL NOQUEUE log records: 
             DNSBL rank 1:          0
             DNSBL rank 2:          0
             DNSBL rank 3:      10368
             DNSBL rank 4:          0
             DNSBL rank 5:      10368
             DNSBL rank 6:      51840
             DNSBL rank 7:          0
             DNSBL rank 8:      46656
             DNSBL rank 9:          0
           DNSBL rank 10+:          0
 
  DNSBL NOQUEUE by domain: 
              example.com:      36288
              example.net:      15552
              example.org:          0
```

