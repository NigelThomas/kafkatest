#!/bin/bash
#
# Do any preproject setup needed before loading the StreamLab projects
#
# Assume we are running in the project directory
. /etc/sqlstream/environment

# dereference any environment vars passed in by SQLSTREAM_APPLICATION_OPTIONS

for opt in $SQLSTREAM_APPLICATION_OPTIONS
do
    echo setting $opt
    export $opt
done

mkdir -p $SQLSTREAM_HOME/classes/net/sf/farrago/dynamic/

echo ... preparing the application schema  
# update setup.sql to replace placeholders with actual values
echo ... running on host=`hostname`
## cat ${EXPERIMENT_NAME}/setup.sql | sed -e "s/%HOSTNAME%/`hostname`/g" -e "s/%FILE_ROTATION_TIME%/${FILE_ROTATION_TIME:=1m}/" >/tmp/setup.sql
cat ${EXPERIMENT_NAME}/setup.sql >/tmp/setup.sql


echo ... installing the application

$SQLSTREAM_HOME/bin/sqllineClient --color=auto --run=/tmp/setup.sql






