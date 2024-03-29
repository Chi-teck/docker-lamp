FROM debian:bullseye

# Set variables.
ENV DUMB_INIT_VERSION=1.2.5 \
    PHPMYADMIN_VERSION=5.2.0 \
    MAILHOG_VERSION=v1.0.1 \
    MHSENDMAIL_VERSION=v0.2.0 \
    BAT_VERSION=0.22.1 \
    TASK_VERSION=v3.19.0 \
    JQ_VERSION=1.6 \
    PHP_VERSION=8.2 \
    NODEJS_VERSION=18 \
    SYMFONY_CLI_VERSION=5.4.10 \
    HOST_USER_NAME=lamp \
    HOST_USER_UID=1000 \
    HOST_USER_PASSWORD=123 \
    MYSQL_ROOT_PASSWORD=123 \
    TIMEZONE=Europe/Moscow \
    DEBIAN_FRONTEND=noninteractive \
    SERVER=apache \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Set server timezone.
RUN echo $TIMEZONE > /etc/timezone && dpkg-reconfigure tzdata

# Update Apt sources.
RUN apt-get update && apt-get -y install wget apt-transport-https lsb-release ca-certificates && \
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

# Install required packages.
RUN apt-get update && apt-get -y install --no-install-recommends apt-utils \
    sudo \
    net-tools \
    apt-utils \
    gnupg \
    curl \
    git \
    vim \
    zip \
    unzip \
    mc \
    silversearcher-ag \
    bsdmainutils \
    man \
    openssh-server \
    patch \
    sqlite3 \
    tree \
    ncdu \
    rsync \
    html2text \
    less \
    bash-completion \
    apache2 \
    nginx \
    mariadb-server \
    mariadb-client \
    libapache2-mod-php$PHP_VERSION \
    php$PHP_VERSION-xdebug \
    php$PHP_VERSION-fpm \
    php$PHP_VERSION-xml \
    php$PHP_VERSION-mysql \
    php$PHP_VERSION-sqlite3 \
    php$PHP_VERSION-zip \
    php$PHP_VERSION-curl \
    php$PHP_VERSION-gd \
    php$PHP_VERSION-mbstring \
    php$PHP_VERSION-bcmath \
    php$PHP_VERSION-cgi \
    php-apcu \
    php$PHP_VERSION-intl \
    php$PHP_VERSION


# Install dumb-init.
RUN wget https://github.com/Yelp/dumb-init/releases/download/v$DUMB_INIT_VERSION/dumb-init_"$DUMB_INIT_VERSION"_amd64.deb && \
    dpkg -i dumb-init_*.deb && \
    rm dumb-init_"$DUMB_INIT_VERSION"_amd64.deb

# Copy sudoers file.
COPY sudoers /etc/sudoers

# Install SSL.
COPY request-ssl.sh /root
RUN bash /root/request-ssl.sh && rm root/request-ssl.sh

# Enable mod rewrite.
RUN a2enmod rewrite ssl

# Update default Apache configuration.
COPY sites-available/apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY sites-available/apache/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf
RUN a2ensite default-ssl.conf

# Update default Nginx configuration.
COPY sites-available/nginx/default /etc/nginx/sites-available/default
RUN sed -i "s/%PHP_VERSION%/$PHP_VERSION/g" /etc/nginx/sites-available/default

# Set server name.
RUN echo 'ServerName localhost' >> /etc/apache2/apache2.conf

# Configure MySQL.
RUN sed -i "s/bind-address/#bind-address/" /etc/mysql/mariadb.conf.d/50-server.cnf && \
    service mariadb start && \
    mysql -uroot -e"SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQL_ROOT_PASSWORD')" && \
    mysql -uroot -e"GRANT ALL ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD'" && \
    mysql -uroot -e"FLUSH PRIVILEGES"

# Override some PHP settings.
COPY 30-local-web.ini /etc/php/$PHP_VERSION/apache2/conf.d/30-local.ini
COPY 30-local-web.ini /etc/php/$PHP_VERSION/fpm/conf.d/30-local.ini
COPY 30-local-cli.ini /etc/php/$PHP_VERSION/cli/conf.d/30-local.ini

# Install Xdebug manager.
COPY xdebug.sh /usr/local/bin/xdebug
RUN chmod +x /usr/local/bin/xdebug && \
    sed -i "s/%PHP_VERSION%/$PHP_VERSION/g" /usr/local/bin/xdebug

# Create host user.
RUN useradd $HOST_USER_NAME -m -u$HOST_USER_UID -Gsudo -s /bin/bash && \
    echo $HOST_USER_NAME:$HOST_USER_PASSWORD | chpasswd

# Install dot files.
COPY vimrc /etc/vim/vimrc.local 
COPY vim/colors/termschool.vim /usr/share/vim/vim82/colors
COPY gitconfig /etc/gitconfig
COPY config /home/$HOST_USER_NAME/.config
RUN sed -i "s/%USER%/$HOST_USER_NAME/g" /home/$HOST_USER_NAME/.config/mc/hotlist && \
    sed -i "s/%PHP_VERSION%/$PHP_VERSION/g" /home/$HOST_USER_NAME/.config/mc/hotlist
COPY bashrc /tmp/bashrc
RUN cat /tmp/bashrc >> /home/$HOST_USER_NAME/.bashrc && rm /tmp/bashrc
COPY inputrc.local /etc/inputrc.local
RUN echo '$include /etc/inputrc.local' >> /etc/inputrc

# Install HR.
RUN wget https://raw.githubusercontent.com/LuRsT/hr/master/hr
RUN chmod +x hr
RUN mv hr /usr/local/bin/

# Install MailHog.
RUN wget https://github.com/mailhog/MailHog/releases/download/$MAILHOG_VERSION/MailHog_linux_amd64 && \
    chmod +x MailHog_linux_amd64 && \
    mv MailHog_linux_amd64 /usr/local/bin/mailhog && \
    wget https://github.com/mailhog/mhsendmail/releases/download/$MHSENDMAIL_VERSION/mhsendmail_linux_amd64 && \
    chmod +x mhsendmail_linux_amd64 && \
    mv mhsendmail_linux_amd64 /usr/local/bin/mhsendmail

# Install jq.
RUN wget https://github.com/stedolan/jq/releases/download/jq-$JQ_VERSION/jq-linux64 && \
    chmod +x jq-linux64 && mv jq-linux64 /usr/local/bin/jq

# Install PhpMyAdmin.
RUN wget https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMIN_VERSION/phpMyAdmin-$PHPMYADMIN_VERSION-all-languages.zip && \
    unzip phpMyAdmin-$PHPMYADMIN_VERSION-all-languages.zip && \
    mv phpMyAdmin-$PHPMYADMIN_VERSION-all-languages /usr/share/phpmyadmin && \
    rm phpMyAdmin-$PHPMYADMIN_VERSION-all-languages.zip
COPY config.inc.php /usr/share/phpmyadmin/config.inc.php
RUN sed -i "s/root_pass/$MYSQL_ROOT_PASSWORD/" /usr/share/phpmyadmin/config.inc.php
COPY sites-available/apache/phpmyadmin.conf /etc/apache2/sites-available/phpmyadmin.conf
RUN a2ensite phpmyadmin

COPY sites-available/nginx/phpmyadmin /etc/nginx/sites-available/phpmyadmin
RUN sed -i "s/%PHP_VERSION%/$PHP_VERSION/g" /etc/nginx/sites-available/phpmyadmin && \
    ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/phpmyadmin

# Install Composer.
RUN curl -sS https://getcomposer.org/installer | php && mv composer.phar /usr/local/bin/composer

# Install Symfony console autocomplete.
RUN mkdir /opt/symfony-console-autocomplete && \
    composer --working-dir=/opt/symfony-console-autocomplete require bamarni/symfony-console-autocomplete:dev-master && \
    ln -s /opt/symfony-console-autocomplete/vendor/bin/symfony-autocomplete /usr/local/bin/symfony-autocomplete

# Install Symfony binary.
RUN curl -1sLf 'https://dl.cloudsmith.io/public/symfony/stable/setup.deb.sh' | bash && \
    apt update && apt install symfony-cli

# Install VarDumper Component.
RUN mkdir /opt/var-dumper && \
    composer --working-dir=/opt/var-dumper require symfony/var-dumper:^5.0 && \
    composer --working-dir=/opt/var-dumper require symfony/console:^5.0 && \
    ln -s /opt/var-dumper/vendor/bin/var-dump-server /usr/local/bin/var-dump-server
COPY dumper.php /usr/share/php

# Install PHP coding standards Fixer.
RUN mkdir /opt/php-cs-fixer && \
    composer --working-dir=/opt/php-cs-fixer require friendsofphp/php-cs-fixer && \
    ln -s /opt/php-cs-fixer/vendor/bin/php-cs-fixer /usr/local/bin/php-cs-fixer

# Install Composer completions.
RUN SHELL=/bin/bash symfony-autocomplete composer  > /etc/bash_completion.d/dcomposer_complete.sh

# Install Bat.
RUN wget -P /tmp https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat-musl_${BAT_VERSION}_amd64.deb && \
    sudo dpkg -i /tmp/bat-musl_${BAT_VERSION}_amd64.deb
    
# Install Task.
RUN wget -P /tmp https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_amd64.deb && \
    sudo dpkg -i /tmp/task_linux_amd64.deb
COPY task.complete.sh /etc/bash_completion.d/task.complete.sh

# Install Node.js and NPM.
RUN curl -sL https://deb.nodesource.com/setup_$NODEJS_VERSION.x | bash - && apt-get install -y nodejs

# Install Yarn.
RUN apt-get update && apt-get install -y curl apt-transport-https && \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y yarn


# Install local tunnel.
RUN npm install -g localtunnel

# Preserve default MySQL data.
RUN mkdir /var/lib/mysql_default && cp -R /var/lib/mysql/* /var/lib/mysql_default

# Set host user directory owner.
RUN chown -R $HOST_USER_NAME:$HOST_USER_NAME /home/$HOST_USER_NAME

# Empty /tmp directory.
RUN rm -rf /tmp/*

# Remove default html directory.
RUN rm -r /var/www/html

# Install cmd.sh file.
COPY cmd.sh /root/cmd.sh
RUN chmod +x /root/cmd.sh

# Default command.
CMD ["dumb-init", "-c", "--", "/root/cmd.sh"]
