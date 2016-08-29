BASE_PATH=/var/www/magento
source $BASE_PATH/.deploy/etc/.config
cd $BASE_PATH/current
rm -rf $BASE_PATH/current/.*
rm -rf $BASE_PATH/current/*
git clone https://github.com/magento/magento2.git ./
git checkout $MAGENTO_VERSION
git reset --hard HEAD
find . -type d -exec chmod 770 {} \; && find . -type f -exec chmod 660 {} \; && chmod u+x bin/magento
composer config secure-http false
composer config repositories.satis composer http://satis.kt-team.de
composer install
mysql -uroot -ptmp -hmysql -e "DROP DATABASE $DBNAME; CREATE DATABASE $DBNAME;";
php -d xdebug.max_nesting_level=500 -f bin/magento setup:install --base-url="$BASEURL" --backend-frontname=admin --db-host=$DBHOST --db-name=$DBNAME --db-user=$DBUSER --db-password="$DBPWD" --admin-firstname=Local --admin-lastname=Admin --admin-email=admin@example.com --admin-user="$ADMINUSER" --admin-password="$ADMINPASSWORD" --language=en_US --currency=USD --timezone=America/Chicago
rm -rf var/generation/* var/cache/*
rm -rf $BASE_PATH/sample-data
git clone https://github.com/magento/magento2-sample-data.git $BASE_PATH/sample-data
cd $BASE_PATH/sample-data
git checkout $MAGENTO_VERSION
git reset --hard HEAD
cd $BASE_PATH/sample-data/dev/tools
chmod 777 -R $BASE_PATH/sample-data
php build-sample-data.php --ce-source="$BASE_PATH/current"
cd $BASE_PATH/current
rm -rf var/generation/* var/cache/*
php -d xdebug.max_nesting_level=500 bin/magento setup:upgrade
git clone $GITUSER@$GITPROVIDER:$GITTEAMNAME/$PROJECT.git tmp-magento
cp tmp-magento/setup.sql $BASE_PATH/current/setup.sql
rm -rf tmp-magento
mysql -uroot -ptmp -h mysql $DBNAME < $BASE_PATH/current/setup.sql
bin/magento setup:di:compile
bin/magento deploy:mode:set production
chown -R www-data:www-data ./*
