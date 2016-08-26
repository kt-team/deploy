#!/bin/sh
BASE_PATH=/var/www/magento

cd $BASE_PATH/current
cd -P ./
path=$(pwd)
cd ../
rm -rf $BASE_PATH/build.tar.gz 
rm -rf $BASE_PATH/current/pub/build.tar.gz 
cd $path
rm -rf .git
tar -czf ../build.tar.gz ./
cd ../
mv build.tar.gz current/pub/