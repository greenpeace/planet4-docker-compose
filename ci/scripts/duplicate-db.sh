#!/usr/bin/env bash

echo "Create planet4 wpunit database"
mysql -u root --password="$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE $TEST_WPUNIT_DB_NAME"
