#!/bin/bash
MESSAGE_PATH="https://tcturf.kt-team.de/message_deploy.php?message=";

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
curl "$MESSAGE_PATH\"start deploy $PROJECT.git to $NOW\""

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
fi
chmod 777 ./
chown $WWWUSER:$WWWGROUP /var/www
echo "change user to $WWWUSER"
mkdir -p /home/$WWWUSER/
mkdir -p /home/$WWWUSER/.composer
cp -rf /root/.ssh /home/$WWWUSER/
chown -R $WWWUSER:$WWWGROUP /home/$WWWUSER/.ssh
chmod 700 /home/$WWWUSER/.ssh
chown -R $WWWUSER:$WWWGROUP /home/$WWWUSER/.composer
chmod 700 /home/www-data/.composer/
id
exec sudo -u $WWWUSER /bin/bash - << eof
id

git clone $GITUSER@$GITPROVIDER:$GITTEAMNAME/$PROJECT.git $NOW

cd $ProjectDir/$NOW
git fetch --all
git reset --hard HEAD
git checkout $RELEASE
git pull

export COMPOSER_PROCESS_TIMEOUT=3000

curl -sS https://getcomposer.org/installer | php
composer config -g github-oauth.github.com $GITHUBTOKEN
composer config -g secure-http false
composer run-script pre-install-cmd
composer install

echo -e "Dump DB to $DBNAME.$NOW.gz"
mysqldump -u$DBUSER -p$DBPWD -h$DBHOST $DBNAME | gzip -c > $ProjectDir/.deploy/sql/dumps/$DBNAME.$NOW.gz

echo "Applying ownership & proper permissions..."
find . -type d -exec chmod 770 {} \; && find . -type f -exec chmod 660 {} \; && chmod u+x bin/magento

ln -s ../../../env.php ./app/etc/

echo "Generate modules in config.php..."
bin/magento module:enable --all

echo "Run post install cmd..."
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

echo "Deploying static view files..."
./bin/magento setup:static-content:deploy en_US
./bin/magento setup:static-content:deploy ru_RU


echo "Applying ownership & proper permissions..."
chmod -R 777 $ProjectDir/$NOW/var/
chmod -R 777 $ProjectDir/$NOW/pub/


echo "Switch to current"
ln -sfn ./$NOW/ $ProjectDir/current
echo 'set \\$MAGE_ROOT /var/www/magento/$NOW;' > /var/www/magento/MAGE_ROOT

bash $ProjectDir/deploy/magento2/deploy_clean.sh
curl "$MESSAGE_PATH\"Finish deploy $PROJECT.git to $NOW\""
exit 0
eof
