FROM ubuntu:14.04

MAINTAINER Sean Cross <xobs@kosagi.com>

ENV APACHE_CONFDIR /etc/apache2
ENV APACHE_ENVVARS $APACHE_CONFDIR/envvars
ENV CODEBENDER_COMPILER_URL https://github.com/codebendercc/compiler.git
ENV CODEBENDER_COMPILER_TAG 7f01d36c128f2c4a62e98f165347f376d1335e40
ENV CODEBENDER_ARDUINO_CORES https://github.com/codebendercc/arduino-core-files/archive/master.zip
ENV CODEBENDER_EXTERNAL_CORES https://github.com/codebendercc/external_cores/archive/master.zip
ENV CODEBENDER_HOME /opt/codebender
ENV CODEBENDER_COMPILER_HOME $CODEBENDER_HOME/compiler
ENV COMPOSER_HOME $CODEBENDER_COMPILER_HOME
ENV CHIBITRONICS_HARDWARE_REPO https://github.com/xobs/arduino-esplanade.git

# Key used by web clients
ENV CODEBENDER_AUTHORIZATION_KEY key123

RUN apt-get update \
    && apt-get install -y \
        php5-intl \
        apache2 \
        libapache2-mod-php5 \
        php-pear \
        php5-xdebug \
        php5-curl \
        php5-sqlite \
        acl \
        curl \
        lame \
        git \
        unzip \
    && apt-get clean

RUN set -ex \
	\
# generically convert lines like
#   export APACHE_RUN_USER=www-data
# into
#   : ${APACHE_RUN_USER:=www-data}
#   export APACHE_RUN_USER
# so that they can be overridden at runtime ("-e APACHE_RUN_USER=...")
	&& sed -ri 's/^export ([^=]+)=(.*)$/: ${\1:=\2}\nexport \1/' "$APACHE_ENVVARS" \
	\
# setup directories and permissions
	&& . "$APACHE_ENVVARS" \
	&& for dir in \
		"$APACHE_LOCK_DIR" \
		"$APACHE_RUN_DIR" \
		"$APACHE_LOG_DIR" \
		/var/www/html \
	; do \
		rm -rvf "$dir" \
		&& mkdir -p "$dir" \
		&& chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$dir"; \
done

# Set up prefork, as well as enabling rewriting and aliases
RUN a2enmod rewrite \
    && a2enmod alias \
    && a2dismod mpm_event \
    && a2enmod mpm_prefork

# logs should go to stdout / stderr
RUN set -ex \
	&& . "$APACHE_ENVVARS" \
	&& ln -sfT /dev/stderr "$APACHE_LOG_DIR/error.log" \
	&& ln -sfT /dev/stdout "$APACHE_LOG_DIR/access.log" \
    && ln -sfT /dev/stdout "$APACHE_LOG_DIR/other_vhosts_access.log"

# PHP files should be handled by PHP, and should be preferred over any other file type
RUN { \
		echo '<FilesMatch \.php$>'; \
		echo '\tSetHandler application/x-httpd-php'; \
		echo '</FilesMatch>'; \
		echo; \
		echo 'DirectoryIndex disabled'; \
		echo 'DirectoryIndex index.php index.html'; \
		echo; \
		echo '<Directory /var/www/>'; \
		echo '\tOptions -Indexes'; \
		echo '\tAllowOverride All'; \
		echo '</Directory>'; \
	} | tee "$APACHE_CONFDIR/conf-available/docker-php.conf" \
	&& a2enconf docker-php

# Download and install the compiler infrastructure
RUN set -ex \
    && mkdir -p $CODEBENDER_HOME \
    && cd $CODEBENDER_HOME \
    && git clone $CODEBENDER_COMPILER_URL $CODEBENDER_COMPILER_HOME \
    && cd $CODEBENDER_COMPILER_HOME \
    && git checkout $CODEBENDER_COMPILER_TAG \
    && mkdir -p Symfony/app/cache Symfony/app/logs \
    && cp Symfony/app/config/parameters.yml.dist Symfony/app/config/parameters.yml \
    && cp apache-config $APACHE_CONFDIR/conf-available/codebender.conf \
    && a2enconf codebender

# Download and install the compiler toolchains
RUN set -ex \
    && curl -o master.zip -L $CODEBENDER_ARDUINO_CORES \
    && unzip -q master.zip \
    && mv arduino-core-files-master $CODEBENDER_HOME/codebender-arduino-core-files \
    && rm -f master.zip \
    && curl -o master.zip -L $CODEBENDER_EXTERNAL_CORES \
    && unzip -q master.zip \
    && mv external_cores-master $CODEBENDER_HOME/external-core-files \
    && rm -f master.zip \
    && cd $CODEBENDER_HOME/codebender-arduino-core-files/v167/hardware \
    && git clone $CHIBITRONICS_HARDWARE_REPO chibitronics

# Change the authorization key
RUN sed -i "s/$(grep authorizationKey $CODEBENDER_COMPILER_HOME/Symfony/app/config/parameters.yml | awk '{print $2}')/"$CODEBENDER_AUTHORIZATION_KEY/g $CODEBENDER_COMPILER_HOME/Symfony/app/config/parameters.yml

# Ensure everything is readable by the Apache user
RUN set -ex \
	&& . "$APACHE_ENVVARS" \
    && chown -R $APACHE_RUN_USER:$APACHE_RUN_GROUP $CODEBENDER_HOME

# Disable xdebug
RUN rm -f /etc/php5/cli/conf.d/20-xdebug.ini /etc/php5/apache2/conf.d/20-xdebug.ini

# Install Php-Composer
RUN set -ex \
	&& . "$APACHE_ENVVARS" \
    && cd $CODEBENDER_COMPILER_HOME/Symfony \
    && su -c "curl -s http://getcomposer.org/installer | php" -s "/bin/sh" $APACHE_RUN_USER \
    && su -c "php composer.phar install" -s "/bin/sh" $APACHE_RUN_USER

# Warm up the caches
RUN set -ex \
	&& . "$APACHE_ENVVARS" \
    && cd $CODEBENDER_COMPILER_HOME/Symfony \
    && su -c "php app/console cache:warmup --env=dev" -s "/bin/sh" $APACHE_RUN_USER \
    && su -c "php app/console cache:warmup --env=prod" -s "/bin/sh" $APACHE_RUN_USER \
    && su -c "php app/console cache:warmup --env=test" -s "/bin/sh" $APACHE_RUN_USER

WORKDIR $CODEBENDER_COMPILER_HOME/Symfony

# Set up our launch script
COPY apache2-foreground /usr/local/bin
RUN chmod a+x /usr/local/bin/apache2-foreground

EXPOSE 80
CMD ["apache2-foreground"]
