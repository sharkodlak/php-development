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
chown -hR www-data:adm /var/www

HASH=$(sha256sum /etc/logrotate.d/php7.1-fpm | cut -d' ' -f1)
if [ "31151b05207fe1cc87583ec8a7d2ffafdbbbebe03fe2f36c2b52904341583881" != "$HASH" ]; then
	cp /vagrant/vendor/sharkodlak/development/filesystem/etc/logrotate.d/php7.1-fpm /etc/logrotate.d/php7.1-fpm
fi

HASH=$(sha256sum /etc/php/7.1/fpm/pool.d/www.conf | cut -d' ' -f1)
if [ "e16d2b414516061f6d6433041f5a854c03ba60929af65c0ae12a2b3880f75450" != "$HASH" ]; then
	patch -b /etc/php/7.1/fpm/pool.d/www.conf < /vagrant/vendor/sharkodlak/development/filesystem/etc/php/7.1/fpm/pool.d/www.conf.patch
fi

HASH=$(sha256sum /etc/nginx/sites-available/default | cut -d' ' -f1)
if [ "3b12ca1e6c37e2bdc4081d9bc948159f170b20acbf9996a93ab7abe9748cf8e2" != "$HASH" ]; then
	cp /vagrant/vendor/sharkodlak/development/filesystem/etc/nginx/sites-available/default /etc/nginx/sites-available/default
fi
