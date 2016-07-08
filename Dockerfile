FROM alpine:3.4

MAINTAINER Aaron Welch "welch@packet.net"

ENV PHPCONF /etc/php5/php.ini 
ENV FPMCONF /etc/php5/php-fpm.conf
ENV COMPOSERHASH e115a8dc7871f15d853148a7fbac7da27d6c0030b848d9b3dc09e2a0388afed865e6a3d6b3c0fad45c48e2b5fc1196ae

RUN apk add --no-cache bash \
    openssh-client \
    wget \
    nginx \
    supervisor \
    curl \
    git \
    php5-fpm \
    php5-pdo \
    php5-pdo_mysql \
    php5-mysql \
    php5-mysqli \
    php5-mcrypt \
    php5-ctype \
    php5-zlib \
    php5-gd \
    php5-intl \
    php5-memcache \
    php5-sqlite3 \
    php5-pgsql \
    php5-xml \
    php5-xsl \
    php5-curl \
    php5-openssl \
    php5-iconv \
    php5-json \
    php5-phar \
    php5-soap \
    php5-dom && \
    mkdir -p /etc/nginx && \
    mkdir -p /var/www/app && \
    mkdir -p /run/nginx && \
    mkdir -p /var/log/supervisor 

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('SHA384', 'composer-setup.php') === '${COMPOSERHASH}') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php --install-dir=/usr/bin --filename=composer && \
    php -r "unlink('composer-setup.php');"

ADD conf/supervisord.conf /etc/supervisord.conf

# Copy our nginx config
RUN rm -Rf /etc/nginx/nginx.conf
ADD conf/nginx.conf /etc/nginx/nginx.conf

# nginx site conf
RUN mkdir -p /etc/nginx/sites-available/ && \
mkdir -p /etc/nginx/sites-enabled/ && \
mkdir -p /etc/nginx/ssl/ && \
rm -Rf /var/www/* && \
mkdir /var/www/html/
ADD conf/nginx-site.conf /etc/nginx/sites-available/default.conf
RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${PHPCONF} && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${PHPCONF} && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${PHPCONF} && \
sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${PHPCONF} && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" ${FPMCONF} && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${FPMCONF} && \
sed -i -e "s/pm.max_children = 4/pm.max_children = 4/g" ${FPMCONF} && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${FPMCONF} && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${FPMCONF} && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${FPMCONF} && \
sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${FPMCONF} && \
sed -i -e "s/user = nobody/user = nginx/g" ${FPMCONF} && \
sed -i -e "s/group = nobody/group = nginx/g" ${FPMCONF} && \
sed -i -e "s/;listen.mode = 0660/listen.mode = 0666/g" ${FPMCONF} && \
sed -i -e "s/;listen.owner = nobody/listen.owner = nginx/g" ${FPMCONF} && \
sed -i -e "s/;listen.group = nobody/listen.group = nginx/g" ${FPMCONF} && \
sed -i -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" ${FPMCONF} &&\
ln -s /etc/php5/php.ini /etc/php5/conf.d/php.ini && \
find /etc/php5/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

ADD scripts/start.sh /bin/start.sh
RUN chmod 755 /bin/start.sh

VOLUME ["/var/www"]

EXPOSE 443 80

CMD ["/bin/start.sh"]
