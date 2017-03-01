BASE_PATH=/var/www/magento
source $BASE_PATH/.deploy/etc/.config

cd $BASE_PATH
rm -rf $BASE_PATH/current
composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition current
cd $BASE_PATH/current
ln -s /root/.composer ./var/composer_home
chmod +x ./bin/magento

mysql -uroot -prosenewt98 -hmysql -e "DROP DATABASE magento2;"
mysql -uroot -prosenewt98 -hmysql -e "CREATE DATABASE magento2 CHARACTER SET utf8 COLLATE utf8_general_ci;"

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


find . -type d -exec chmod 770 {} \; && find . -type f -exec chmod 660 {} \; && chmod u+x bin/magento

composer config secure-http false
composer config repositories.satis composer http://satis.kt-team.de


rm -rf var/generation/* var/cache/*

bin/magento deploy:mode:set $DEPLOYMODE

php ./bin/magento sampledata:deploy
php ./bin/magento module:enable --all
php ./bin/magento setup:upgrade

chown -R www-data:www-data ./*
