if [ ! -e /etc/timezone ]; then
	cp /vagrant/vendor/sharkodlak/development/filesystem/etc/timezone /etc/timezone
	chmod 644 /etc/timezone
	chown root:root /etc/timezone
	dpkg-reconfigure --frontend noninteractive tzdata
fi

if [ ! -d /var/log/www ]; then
	mkdir --mode=774 /var/log/www
fi
