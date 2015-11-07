#!/bin/bash

# discover_databases.sh enumerates all available databases in local server
#    Copyright (C) 2015 Holocorp Group de Mexico
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


# getlistenerproperty()
#
# get a property from stdin (listener.ora format) for a specific listener and
# print it on stdout. this awk script will tokenize the listener file so that
# it can find the property no matter what format the file is in. it will only
# print the first match (for example an address).
#   param 1: top-level property filter (e.g. listener name)
#   param 2: leaf property to get (e.g. host, port, protocol)
# by Jeremy Schneider - ardentperf.com

OSTYPE=`uname -s`
HOSTNAME=`hostname`

shopt -s expand_aliases

searchpaths=`find /*ora* -name listener.ora -prune 2>/dev/null| grep -vi sample`

if [ ${OSTYPE} = "Linux" ]
then
     perawk=awk

elif [ ${OSTYPE} = "SunOS"  ]
then
     perawk=nawk

elif [ ${OSTYPE} = "AIX" ]
then
     perawk=nawk

elif [ ${OSTYPE} = "HP-UX" ]
then
     perawk=awk
fi

getlistenerproperty() {
  sed -e 's/=/`=/g' -e 's/(/`(/g' -e 's/)/`)/g'|perawk 'BEGIN{level=1} {
    wrote=0
    split($0,tokens,"`")
    i=1; while(i in tokens) {
      if(tokens[i]~"^[(]") level++
      if(tokens[i]~"^[)]") level--
      if(level==1&&i==1&&tokens[i]~"[A-Za-z]") TOP=tokens[i]
      if(toupper(TOP)~toupper("^[ \t]*'"$1"'[ \t]*$")) {
        if(propertylvl) {
          if(level>=propertylvl) {
            if(tokens[i]~"^="&&level==propertylvl) printf substr(tokens[i],2)
              else printf tokens[i]
            wrote=1
          } else propertylvl=0
          found=1
        }
        if(!found&&toupper(tokens[i])~toupper("^[(]?[ \t]*'"$2"'[ \t]*$")) propertylvl=level
      }
      i++
    }
    if(wrote) printf "\n"
  }'
}

for i in `ps -ef | grep pmon | grep -v grep | grep -v $perawk | $perawk '{printf "%s\n", toupper(substr($0,index($0, "ora_pmon") + 9))}'`
do
	for j in $searchpaths; do
		dbport=`cat $j | getlistenerproperty LISTENER_$i port`
		if [ -n "$dbport" ]; then
			break
		fi
	done
	echo "Database $i, Port $dbport"
done
