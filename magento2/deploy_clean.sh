#!/bin/bash
set -e # EXIT on ANY error
BASE_PATH=/var/www/magento
cd $BASE_PATH

rm -rf /etc/php5/cli/conf.d/20-xdebug.ini
rm -rf /etc/php/5.6/cli/conf.d/20-xdebug.ini
rm -rf /etc/php/7.0/cli/conf.d/20-xdebug.ini

set -e # EXIT on ANY error
NOW=$(date +"%Y-%m-%d-%H-%M")

ProjectDir=$BASE_PATH
if [ ! -f $ProjectDir/.deploy/etc/.config ]; then
    exit "NO VAR FILE FOUND"
fi
#LOADING VARS FROM FILE"
source $ProjectDir/.deploy/etc/.config

cd $ProjectDir

echo -e "KEEP=$KEEP , start checks"

test $KEEP -gt 0 && NEEDREMOVE=1

if [ $NEEDREMOVE ]; then
    echo -e "REMOVING OLD RELEASES, KEEP=[$KEEP]"
    #clean old releases
    YEAR=`date +"%Y"`
    for i in `ls -d */ | sort -r |  grep "$YEAR-"| grep -v "$NOW" | tail -n+$KEEP`
    do
        rm -rf ./$i/
    done
    #REMOVING OLD MYSQL DUMPS
    for i in `find $ProjectDir/.deploy/sql/dumps -maxdepth 1 -type f -name "$DBNAME.$YEAR*.gz" | sort -r |  grep -v "$DBNAME.$NOW.gz" | tail -n+$KEEP`
    do
        rm -f ./$i
    done

fi
