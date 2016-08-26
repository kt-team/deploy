#!/bin/bash
set -e # EXIT on ANY error
BASE_PATH=/var/www/magento
cd $BASE_PATH
#variables
PWD=$( pwd )
NOW=$(date +"%Y-%m-%d-%H-%M")
ProjectDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd $ProjectDir

if [ ! -f $ProjectDir/.deploy/etc/.config ]; then
    exit "NO VAR FILE FOUND"
fi
#LOADING VARS FROM FILE"
source $ProjectDir/.deploy/etc/.config

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

echo "GIT: git clone $GITUSER@$GITPROVIDER:$GITTEAMNAME/$PROJECT.git $NOW"

git clone $GITUSER@$GITPROVIDER:$GITTEAMNAME/$PROJECT.git $NOW

#Preparing directories
mkdir -p $NOW/app/etc $NOW/media $NOW/var
echo $RELEASE > $NOW/release

#get to folder and deploy
cd $ProjectDir/$NOW
git fetch --all
git reset --hard HEAD
git checkout $RELEASE
git pull

# upgrade code
#curl -sS https://getcomposer.org/installer | php
cp ../composer.phar ./
php composer.phar clear-cache
php composer.phar install

cd $ProjectDir/.deploy/dirs
for i in * ; do
  if [ -d "$i" ]; then
	echo -e "Ln dir: $i"
	rm -rf $ProjectDir/$NOW/$i ; ln -s ./../$i $ProjectDir/$NOW/$i
  fi
done

#rm -rf ./var ; ln -s ./../var var
#rm -rf ./media ; ln -s ./../media media

cd $ProjectDir

if [ -d "./current/" ]
then
    touch current/maintenance.flag
fi

cp -R $ProjectDir/.deploy/etc/root/* $ProjectDir/$NOW/

#update database
echo -e "Dump DB to $DBNAME.$NOW.gz"
mysqldump -u$DBUSER -p$DBPWD -h$DBHOST $DBNAME | gzip -c > $ProjectDir/.deploy/sql/dumps/$DBNAME.$NOW.gz

if [ $DROPDB -eq "1"  ]; then
    echo -e "\n*******************************************\n"
    echo -e "WILL DROP DB NOW. SHUTDOWN THE SCRIPT IF YOU DON'T WANT IT. PAUSED FOR 10 SEC"
    echo -e "\n*******************************************\n"
    sleep 10
    echo -e "$NOW -> DROPping DATABASE" >> ./deploy.log
    mysql -u$DBUSER -p$DBPWD -h$DBHOST -e"DROP DATABASE IF EXISTS $DBNAME;"
    mysql -u$DBUSER -p$DBPWD -h$DBHOST -e"CREATE DATABASE $DBNAME CHARACTER SET utf8 COLLATE utf8_general_ci;"
    pv $ProjectDir/.deploy/sql/$DBSQLFILE | gunzip | mysql -u$DBUSER -p$DBPWD -h$DBHOST $DBNAME
fi

if [ `ls -1 $ProjectDir/.deploy/sql/insert/*.tar.gz 2>/dev/null | wc -l ` -gt 0 ]; then
    echo "DUMP DB: $DBNAME"
    mysqldump -u$DBUSER -p$DBPWD -h$DBHOST $DBNAME | gzip -c > $CUR_dir/.deploy/sql/dumps/$DBNAME.$NOW.gz
    echo "DROP & CREATE DB: $DBNAME"
    mysql -u$DBUSER -p$DBPWD -h$DBHOST -e"DROP DATABASE IF EXISTS $DBNAME;"
    mysql -u$DBUSER -p$DBPWD -h$DBHOST -e"CREATE DATABASE $DBNAME CHARACTER SET utf8 COLLATE utf8_general_ci;"
    for tarfile in $ProjectDir/.deploy/sql/insert/*.tar.gz; do 
        mkdir $ProjectDir/.deploy/sql/insert/tmp
        tar -xvzf $tarfile -C $ProjectDir/.deploy/sql/insert/tmp
        find $ProjectDir/.deploy/sql/insert/tmp -name '*.sql' | awk '{ print "source",$0 }' | mysql --batch -u$DBUSER -p$DBPWD -h$DBHOST $DBNAME
        rm -rf $ProjectDir/.deploy/sql/insert/tmp
        mv $tarfile $ProjectDir/.deploy/sql/done/
    done
fi


cd $ProjectDir/$NOW/
rm -rf var/cache/*
#n98-magerun.phar cache:clean
php ./index.php
cd ../
chown -R $WWWUSER:$WWWGROUP $NOW

#switch
ln -sfn ./$NOW/ ./current

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


echo -e `pwd`


if [ -f $ProjectDir/.deploy/sql/init.sql ]; then
    pv $ProjectDir/.deploy/sql/init.sql | mysql -u$DBUSER -p$DBPWD -h$DBHOST $DBNAME
fi


if [ -f $ProjectDir/.deploy/etc/post-deploy.sh ]; then
    source $ProjectDir/.deploy/etc/post-deploy.sh
fi

exit 0
