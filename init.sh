if [ ! -e /etc/timezone ]; then
	cp /vagrant/vendor/sharkodlak/development/filesystem/etc/timezone /etc/timezone
	chmod 644 /etc/timezone
	chown root:root /etc/timezone
	dpkg-reconfigure --frontend noninteractive tzdata
fi

if [ ! -d /var/log/www ]; then
	mkdir --mode=774 /var/log/www
fi

HASH=$(sha256sum /etc/logrotate.d/php7.1-fpm | cut -d' ' -f1)
if [ "31151b05207fe1cc87583ec8a7d2ffafdbbbebe03fe2f36c2b52904341583881" != "$HASH" ]; then
	cp /vagrant/vendor/sharkodlak/development/filesystem/etc/logrotate.d/php7.1-fpm /etc/logrotate.d/php7.1-fpm
fi

HASH=$(sha256sum /etc/php/7.1/fpm/pool.d/www.conf | cut -d' ' -f1)
if [ "22c5ea7ceabbcafc9e6066cb9facb736914e0bcc106748052a0f77c377feb9df" != "$HASH" ]; then
	patch -b /etc/php/7.1/fpm/pool.d/www.conf < /vagrant/vendor/sharkodlak/development/filesystem/etc/php/7.1/fpm/pool.d/www.conf.patch
fi
