#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "$DIR/ini.sh" # load INI functions

function fileHash {
	sha256sum $1 | cut -d' ' -f1
}

function patchFile {
	if [ -z $4 ]; then
		local source="$1.patch"
	else
		local source="$(dirname "$1")/$4"
	fi
	local hash=$(fileHash $1)
	if [ "$2" == "$hash" ]; then
		return 1
	fi
	if [[ -z "$3" || "$3" == 0 ]]; then
		patch -b "$1" < "/vagrant/vendor/sharkodlak/development/filesystem$source"
	else
		echo "Reverting patch..."
		patch -R "$1" < "/vagrant/vendor/sharkodlak/development/filesystem$source"
	fi
}

function updateFile {
	if [ -z $3 ]; then
		local source="$1"
	else
		local source="$(dirname "$1")/$3"
	fi
	local hash=$(fileHash $1)
	local status
	if [ "$2" == "$hash" ]; then
		echo skipping already up to date file $1
		return 1
	fi
	echo updating file $1
	cp "/vagrant/vendor/sharkodlak/development/filesystem$source" "$1"
	status=$?
	if [ ! $status ]; then
		echo -e "\e[0;31mupdate failed"
	fi
	return $status
}

function copyMissingFile {
	if [ ! -e $1 ]; then
		echo copying missing file $1
		cp "/vagrant/vendor/sharkodlak/development/$1" "$1"
	fi
}


usermod -a -G adm vagrant

if updateFile /etc/locale.gen $(fileHash /vagrant/vendor/sharkodlak/development/filesystem/etc/locale.gen); then
	locale-gen
fi

if updateFile /etc/timezone $(fileHash /vagrant/vendor/sharkodlak/development/filesystem/etc/timezone); then
	chmod 644 /etc/timezone
	chown root:root /etc/timezone
	dpkg-reconfigure --frontend noninteractive tzdata
fi

if [ ! -L /var/www ]; then
	echo Droping /var/www and linking it to /vagrant/src/www
	rm -rf /var/www
	ln -sT /vagrant/src/www/ /var/www
fi

cp -r /vagrant/vendor/sharkodlak/development/filesystem/var/www/* /var/www/

if [ ! -d /var/log/www ]; then
	echo Creating /var/log/www
	mkdir --mode=774 /var/log/www
fi

touch /var/log/www/access.log /var/log/www/error.log /var/log/www/slow.log
chown -hR www-data:adm /var/www /var/log/www /var/log/php7.3-fpm.log
chmod -R 751 /var/log/www/
chmod 640 /var/log/php7.3-fpm.log

updateFile /etc/logrotate.d/php7.3-fpm 31151b05207fe1cc87583ec8a7d2ffafdbbbebe03fe2f36c2b52904341583881
patchFile /etc/php/7.3/fpm/pool.d/www.conf 5edb1d606d70d3fb1267507bb8943917a9008cd0bd3013005c9144992761581e
service php7.3-fpm reload

updateFile /etc/nginx/sites-available/default 3b12ca1e6c37e2bdc4081d9bc948159f170b20acbf9996a93ab7abe9748cf8e2
service nginx reload

apt-get install -y postgresql php7.3-cli php-pgsql php-xdebug php-xml

copyMissingFile provision/.private/postgres.ini
parseIniFile provision/.private/postgres.ini

if [[ "$dbname" && "${username[$commonUserIndex]}" ]]; then
	echo PostgreSQL listen on all interfaces
	patchFile /etc/postgresql/11/main/postgresql.conf 27b892ad9084e22e5967ba49881eeba26eb8f5accac22cb754201ba0a0cd226a
	if [ $? ]; then
		echo PostgreSQL allow temporal access without password
		patchFile /etc/postgresql/11/main/pg_hba.conf b888e9bda2f4816171fafb61f0d204d91c4f438f885ef8fd651f908c2f7029a5
		service postgresql reload

		echo Create database and users
		commonUserIndex=$(getIniSectionIndex commonUser)
		powerUserIndex=$(getIniSectionIndex powerUser)
		psql -U postgres -c "CREATE ROLE commonUsers;"
		psql -U postgres -c "CREATE ROLE powerUsers CREATEDB CREATEROLE REPLICATION IN ROLE commonUsers;"
		psql -U postgres -c "CREATE DATABASE \"$dbname\" OWNER powerUsers ENCODING 'UTF8';"
		psql -U postgres -c "CREATE ROLE ${username[$powerUserIndex]} LOGIN ENCRYPTED PASSWORD '${password[$powerUserIndex]}' IN ROLE powerUsers;"
		psql -U postgres -c "CREATE ROLE ${username[$commonUserIndex]} LOGIN ENCRYPTED PASSWORD '${password[$commonUserIndex]}' IN ROLE commonUsers;"
		psql -U postgres -d "$dbname" -c "SET ROLE ${username[$powerUserIndex]}; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ${username[$commonUserIndex]};"

		mkdir -p -m755 "/etc/webconf/$dbname" && chown -R www-data:adm "/etc/webconf"
		dbConnectFile="/etc/webconf/$dbname/connect.pgsql"
		echo "pgsql:host=localhost;dbname=$dbname;user=${username[$commonUserIndex]};password=${password[$commonUserIndex]}" > $dbConnectFile
		dbPowerUserConnectFile="/etc/webconf/$dbname/connect.powerUser.pgsql"
		echo "pgsql:host=localhost;dbname=$dbname;user=${username[$powerUserIndex]};password=${password[$powerUserIndex]}" > $dbPowerUserConnectFile
		chown www-data:adm $dbConnectFile $dbPowerUserConnectFile
		chmod 0640 $dbConnectFile $dbPowerUserConnectFile

		echo Revert temporal access without password
		patchFile /etc/postgresql/11/main/pg_hba.conf anyHash -R
		echo PostgreSQL allow only password access
		patchFile /etc/postgresql/11/main/pg_hba.conf b888e9bda2f4816171fafb61f0d204d91c4f438f885ef8fd651f908c2f7029a5 0 pg_hba.conf.password.patch
		service postgresql reload
	fi
fi
