#!/bin/sh

#
# Copyright (c) 2013, 2014 Mike Miller <mmiller@mgm51.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

# This script resides here: http://archive.mgm51.com/sources/

#
# A simple log file scanner for the Postfix Postscreen service.
#
# This script gives an overview of how Postscreen is performing.
#
# Note that detailed accuracy was not the goal.  Look at this script
# more as a quick summarized overview.
#
#
# version history
#  20130129 1.0 mm - initial release
#  20130129 1.1 mm - removed deferrals from reject calculation
#  20130129 1.2 mm - major re-structure based upon feedback from
#		      postfix-users mailing list
#  20130201 1.3 mm - some formatting changes
#		   - revert to grep scanning for dnsblog entries
#  20130203 1.4 mm - corrected two issues with regex for DNSBL block 
#		      counts greater than 9
#		   - tightened up the regex for CONNECT, PASS NEW and
#		      PASS OLD to avoid false positives
#		   - added option to enable the handling of deep
#		      protocol tests
#  20140429 1.5 mm - changed `expr ... ` to $(( ... ))
#  20140716 1.6 mm - cleaned up the output formatting, moved to printf
#		      for clearer formatting
#		   - changed from linear to loop processing in many 
#		      places
#		   - moved some values from hard-coded to configuration 
#		      variables
#  20140815 1.7 mm - cleaned up some comments
#  20140929 1.8 mm - fixed bug in deep protocol tests check (thanks AE)
#

get_config_param() {
	param=$1
	postconf -x $param | sed -e 's/.*=\s*//'
}

#
##
#
# Configuration block
#
# Adjust if "deep protocol tests" are enabled in main.cf (yes/no)
DeepProtocolTestsEnabled=no
pipelining_enable=$(get_config_param postscreen_pipelining_enable)
non_smtp_command_enable=$(get_config_param postscreen_non_smtp_command_enable)
bare_newline_enable=$(get_config_param postscreen_bare_newline_enable)
if [[ $pipelining_enable == yes || $non_smtp_command_enable == yes || $bare_newline_enable == yes ]]; then
	DeepProtocolTestsEnabled=yes
fi

# Set to the same value as postscreen_dnsbl_threshold in main.cf,
#  this sets the lower limit for reporting.  1 is an OK default
# PFPSConfDNSBLThreshold=1
PFPSConfDNSBLThreshold=$(get_config_param postscreen_dnsbl_threshold)


# DNSBL's to process for "DNS black list log records" section,
#  the postscreen_dnsbl_sites in main.cf
#  (quoted string of space-delimited DNSBL sites)
# DNSBLList="zen.spamhaus.org bl.spamcop.net b.barracudacentral.org"
DNSBLList=$(get_config_param postscreen_dnsbl_sites | sed -e 's/\*[-0-9]*//g')


# Domains to process for "DNSBL NOQUEUE by domain" section,
#  the domains processed by this MTA
#  (quoted string of space-delimited domains)
# DomainList="example.com example.net example.org"
DomainList=$(get_config_param mydestination | sed -e 's/,/ /g')

# The format for mktemp template differs among OS's,
#  make sure you put a suitable template format here.
mktempTemplate=/tmp/pslogscan.XXXXXXXX

# The width of the output's first field.  Usually, 25 is OK, but
#  if there are long domain names, increase the number
Field1Width=25

# The width of the output's second field,  Usually 10 is OK, but
#  if the numbers overflow the width, increase the number
Field2Width=10

#
# End of configuration
##
# Processing follows
#


if [[ $# = 0 ]]; then 
	echo Usage: $0 maillogfile
	exit 1
fi

if [[ ! -f $1 ]]; then
	echo $1 does not exist.
	exit 1
fi


File2Scan=$1
echo Scanning ${File2Scan}

PostscreenLog=$(mktemp ${mktempTemplate})
TmpFile=$(mktemp ${mktempTemplate})

echo " "

# Look only at the postscreen log records
grep " postfix/postscreen\[" ${File2Scan} > ${PostscreenLog}


# Gather some stats

echo    "  Screening status log records:"

ConnectRecs=$(grep -c "\]: CONNECT from " ${PostscreenLog})
printf "%${Field1Width}s: %${Field2Width}s\n" "CONNECT" ${ConnectRecs}

PassNewRecs=$(grep -c "\]: PASS NEW " ${PostscreenLog})
printf "%${Field1Width}s: %${Field2Width}s\n" "PASS NEW" ${PassNewRecs}

PassOldRecs=$(grep -c "\]: PASS OLD " ${PostscreenLog})
printf "%${Field1Width}s: %${Field2Width}s\n" "PASS OLD" ${PassOldRecs}

WhiteListRecs=$(grep -c "\]: WHITELISTED " ${PostscreenLog})
printf "%${Field1Width}s: %${Field2Width}s\n" "WHITELISTED" ${WhiteListRecs}

BlackListRecs=$(grep -c "\]: BLACKLISTED " ${PostscreenLog})
printf "%${Field1Width}s: %${Field2Width}s\n" "BLACKLISTED" ${BlackListRecs}

echo " "



if [ ${DeepProtocolTestsEnabled} = "no" ] ; then
	NumDeflected=$((${ConnectRecs} - ${WhiteListRecs} - ${PassOldRecs} - ${PassNewRecs}))
else
	NumDeflected=$((${ConnectRecs} - ${WhiteListRecs} - ${PassOldRecs}))
fi


PctDeflected=0
if [ ${ConnectRecs} != 0 ] ; then
	 PctDeflected=$((100 * ${NumDeflected} / ${ConnectRecs}))
fi

printf "%${Field1Width}s: %${Field2Width}s  (%s%%)\n"  "rejected"  ${NumDeflected} ${PctDeflected}

echo " "
echo " "


echo    "  Protocol error log records:"
for PclErr in HANGUP PREGREET "BARE NEWLINE" "COMMAND TIME LIMIT" "COMMAND PIPELINING" ; do
	Search="\]: ${PclErr} "
	Count=$(grep -c "${Search}" ${PostscreenLog})
	printf "%${Field1Width}s: %${Field2Width}s\n" "${PclErr}" ${Count}
done

echo " "



echo    "  DNS black list log records:"
grep " listed by domain " ${File2Scan} > ${TmpFile}
for DNSBL in ${DNSBLList} ; do
	Search=" listed by domain ${DNSBL} as "
	Count=$(grep -c "${Search}" ${TmpFile})
	printf "%${Field1Width}s: %${Field2Width}s\n" ${DNSBL} ${Count}
done

echo " "



echo "  DNSBL NOQUEUE log records: "
# Note that only blocked senders make it into the log file
grep "\]: DNSBL rank " ${PostscreenLog} > ${TmpFile}

for Rank in 1 2 3 4 5 6 7 8 9 ; do
	test ${PFPSConfDNSBLThreshold} -gt ${Rank} && continue 
	Count=$(grep -c "DNSBL rank ${Rank} for" ${TmpFile})
	printf "%${Field1Width}s: %${Field2Width}s\n" "DNSBL rank ${Rank}" ${Count}
done

Count=$(grep -c "DNSBL rank [1-9][0-9] for" ${TmpFile})
printf "%${Field1Width}s: %${Field2Width}s\n" "DNSBL rank 10+" ${Count}

echo " "


echo "  DNSBL NOQUEUE by domain: "
grep " blocked using " ${PostscreenLog} > ${TmpFile}
for Domain in ${DomainList} ; do
	Count=$(grep -c "\]: NOQUEUE.*550 5.7.1 Service unavailable;.*blocked using.*${Domain}" ${TmpFile})
	printf "%${Field1Width}s: %${Field2Width}s\n" ${Domain} ${Count}
done



# Cleanup
test -f ${PostscreenLog} && rm ${PostscreenLog}
test -f ${TmpFile} && rm ${TmpFile}

echo " "
