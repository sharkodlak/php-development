#!/bin/bash

function fileHash {
	sha256sum $1 | cut -d' ' -f1
}

function patchFile {
	if [ -z $3 ]; then
		local source="$1.patch"
	else
		local source="$(dirname "$1")/$3"
	fi
	local hash=$(fileHash $1)
	if [ "$2" == "$hash" ]; then
		return 1
	fi
	patch -b "$1" < "/vagrant/vendor/sharkodlak/development/filesystem/$source"
}

function updateFile {
	if [ -z $3 ]; then
		local source="$1"
	else
		local source="$(dirname "$1")/$3"
	fi
	local hash=$(fileHash $1)
	if [ "$2" == "$hash" ]; then
		return 1
	fi
	cp "/vagrant/vendor/sharkodlak/development/filesystem/$source" "$1"
}

usermod -a -G adm vagrant

if [ ! -e /etc/timezone ]; then
	cp /vagrant/vendor/sharkodlak/development/filesystem/etc/timezone /etc/timezone
	chmod 644 /etc/timezone
	chown root:root /etc/timezone
	dpkg-reconfigure --frontend noninteractive tzdata
fi

if [ ! -d /var/log/www ]; then
	mkdir --mode=774 /var/log/www
fi

cp -r /vagrant/vendor/sharkodlak/development/filesystem/var/www/* /var/www/
chown -hR www-data:adm /var/www /var/log/www /var/log/php7.1-fpm.log
chmod -R 640 /var/log/www/ /var/log/php7.1-fpm.log

updateFile /etc/logrotate.d/php7.1-fpm 31151b05207fe1cc87583ec8a7d2ffafdbbbebe03fe2f36c2b52904341583881
patchFile /etc/php/7.1/fpm/pool.d/www.conf 5edb1d606d70d3fb1267507bb8943917a9008cd0bd3013005c9144992761581e
updateFile /etc/nginx/sites-available/default 3b12ca1e6c37e2bdc4081d9bc948159f170b20acbf9996a93ab7abe9748cf8e2

apt-get install -y postgresql php-pgsql php-xdebug

# PostgreSQL listen on all interfaces
patchFile /etc/postgresql/9.4/main/postgresql.conf 0560ef2b96e5e2ded5e4152f5fa8c3eca78058148cae105165ac0505d254f5a0
if [ $? = 0 ]; then
	# PostgreSQL allow temporal access without password
	patchFile /etc/postgresql/9.4/main/pg_hba.conf 0560ef2b96e5e2ded5e4152f5fa8c3eca78058148cae105165ac0505d254f5a0 pg_hba.conf.trust.patch

	service postgresql reload

	psql -c "CREATE ROLE 'commonUsers';"
	read -p "Database name: " dbname
	psql -c "CREATE DATABASE '$dbname' OWNER 'commonUsers' ENCODING 'UTF8';"
	psql -c "CREATE ROLE 'powerUsers' CREATEDB CREATEROLE REPLICATION IN ROLE 'commonUsers';"
	read -p 'PostgreSQL common user (read only access) username: ' username
	read -sp 'Password: ' password
	psql -c "CREATE ROLE '$username' LOGIN ENCRYPTED PASSWORD '$password' IN ROLE 'commonUsers';"
	echo "pgsql:host=localhost;dbname=$dbname;user=$username;password=$password" > "/etc/postgresql/9.4/main/connect.$dbname.pgsql"

	# PostgreSQL allow only password access
	patchFile /etc/postgresql/9.4/main/pg_hba.conf 0560ef2b96e5e2ded5e4152f5fa8c3eca78058148cae105165ac0505d254f5a0

	service postgresql reload
fi
