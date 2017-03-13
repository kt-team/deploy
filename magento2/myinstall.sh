BASE_PATH=/var/www/magento
source $BASE_PATH/.deploy/etc/.config

cd $BASE_PATH
rm -rf $BASE_PATH/current

echo "Downloading the Magento CE metapackage..."
composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition current

cd $BASE_PATH/current
ln -s /root/.composer ./var/composer_home
chmod +x ./bin/magento

echo "Drop and create database $DBNAME..."
mysql -u$DBUSER -p$DBPWD -h$DBHOST -e "DROP DATABASE $DBNAME;" 
mysql -u$DBUSER -p$DBPWD -h$DBHOST -e "CREATE DATABASE $DBNAME CHARACTER SET utf8 COLLATE utf8_general_ci;"

echo "Running Magento 2 setup script..."
php ./bin/magento setup:install \
--backend-frontname=admin \
  --db-host=$DBHOST \
  --db-name=$DBNAME \
  --db-user=$DBUSER \
  --db-password=$DBPWD \
  --base-url=$BASEURL \
  --admin-firstname=Admin \
  --admin-lastname=User \
  --admin-email=admin@kt-team.de \
  --admin-user=magento2 \
  --admin-password=magento2


echo "Set permissions for shared hosting..."
find . -type d -exec chmod 770 {} \; && find . -type f -exec chmod 660 {} \; && chmod u+x bin/magento

echo "Add satis to composer repositories..."
composer config secure-http false
composer config repositories.satis composer http://satis.kt-team.de

echo "Clean cache and generation..."
rm -rf var/generation/* var/cache/* var/page_cache/*

echo "Set deploy mode to $DEPLOYMODE..."
bin/magento deploy:mode:set $DEPLOYMODE

echo "Running install sample data..."
php ./bin/magento sampledata:deploy
php ./bin/magento module:enable --all
php ./bin/magento setup:upgrade

echo "Set owner www-data..."
chown -R www-data:www-data ./*
echo "The setup script has completed execution."
