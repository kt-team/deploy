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

echo "DISKSPACEBUFFER: $DISKSPACEBUFFER";

#CHECKING DISK SPACE
CurrDirAllSize=`du -Lc $ProjectDir/current | tail -n-1 | awk '{print $1}'`
CurrDirMediaSize=`du -Lc $ProjectDir/media | tail -n-1 | awk '{print $1}'`
CurrDirVarSize=`du -Lc $ProjectDir/var | tail -n-1 | awk '{print $1}'`
SpaceAvailable=`df $PWD | awk '/[0-9]%/{print $(NF-2)}'`
SpaceNeeded=`expr $CurrDirAllSize - $CurrDirMediaSize - $CurrDirVarSize + $DISKSPACEBUFFER`
echo "Checking disk space: needed=$SpaceNeeded, available=$SpaceAvailable"

if [ $SpaceAvailable -lt $SpaceNeeded ]; then
    echo -e "NO DISK SPACE AVAILABLE! ABORTING TO PREVENTING ERRORS. Take a look on DISKSPACEBUFFER var in config"
    exit 1
fi

git clone $GITUSER@$GITPROVIDER:$GITTEAMNAME/$PROJECT.git $NOW

cd $ProjectDir/$NOW
git fetch --all
git reset --hard HEAD
git checkout $RELEASE
git pull

export COMPOSER_PROCESS_TIMEOUT=3000

curl -sS https://getcomposer.org/installer | php
composer config -g github-oauth.github.com a77c3307be54e496d22e72896570626e7a4cd9d8
composer config -g secure-http false
composer run-script pre-install-cmd
composer install -vvv


echo -e "Dump DB to $DBNAME.$NOW.gz"
mysqldump -u$DBUSER -p$DBPWD -h$DBHOST $DBNAME | gzip -c > $ProjectDir/.deploy/sql/dumps/$DBNAME.$NOW.gz

echo "Applying ownership & proper permissions..."
find . -type d -exec chmod 770 {} \; && find . -type f -exec chmod 660 {} \; && chmod u+x bin/magento
# echo "Start install magento process..."
# php -d xdebug.max_nesting_level=500 -f bin/magento setup:install --base-url="$BASEURL" --backend-frontname=admin --db-host="$DBHOST" --db-name="$DBNAME" --db-user="$DBUSER" --db-password="$DBPWD" --admin-firstname=Local --admin-lastname=Admin --admin-email=admin@example.com --admin-user="admin" --admin-password="123q123q" --language=en_US --currency=USD --timezone=America/Chicago
#./bin/magento indexer:reindex

ln -s ../../../env.php ./app/etc/
ln -s ../../../config.php ./app/etc/

composer run-script post-install-cmd

echo "Symlink to media..."
rm -fr $ProjectDir/$NOW/pub/media
ln -s $ProjectDir/media/ $ProjectDir/$NOW/pub/media


echo "Clean cache..."
rm -rf var/cache/* var/page_cache/* var/generation/*

echo "Setup upgrade and dicompile..."
./bin/magento setup:upgrade
./bin/magento setup:di:compile


echo "Set magento2 deploy mode to $DEPLOYMODE"
./bin/magento deploy:mode:set $DEPLOYMODE --skip-compilation

#if [ "$DEPLOYMODE" == "production" ]; then
echo "Deploying static view files..."
# For example $LOCALES value: en_US ru_RU
if [ -z "$LOCALES" ]; then
    LOCALES="en_US ru_RU"
fi

if [ -z "$THEME" ]; then
    THEME=""
else
    THEME="-t Magento/backend $THEME"
fi
./bin/magento setup:static-content:deploy $THEME $LOCALES
#fi


echo "Applying ownership & proper permissions..."
chown -R $WWWUSER:$WWWGROUP $ProjectDir/
chmod -R 777 $ProjectDir/$NOW/var/
chmod -R 777 $ProjectDir/$NOW/pub/


echo "Switch to current"
ln -sfn ./$NOW/ $ProjectDir/current


echo -e "KEEP=$KEEP , start checks"

test $KEEP -gt 0 && NEEDREMOVE=1
cd $ProjectDir
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


echo -e `pwd`


exit 0
