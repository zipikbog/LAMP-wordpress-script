#!/bin/bash
wp_root_password="password"
wp_dataname="wordpress"
wp_datauser="wp"
wp_datapassword="password"
path_wp="/var/www"
apache_path="/etc/apache2"
nginx_path="/etc/nginx"
nginx_content=$(<"$nginx_path/sites-enabled/default")
###########
nginx_conf=$(cat << EOF
server {
        listen 443 ssl;

        ssl_certificate /etc/nginx/ssl/nginx.crt;
        ssl_certificate_key /etc/nginx/ssl/nginx.key;

        server_name www.up4soft.test up4soft.test;
#       root /var/www;

        location /wordpress/ {

                proxy_pass http://localhost:8080/;
                include /etc/nginx/proxy_params;
}
        location /site {
                alias /var/www/site;
                index index.html;
}

}


server {
        listen 80;
        server_name www.task1-up4soft.test task1-up4soft.test;
        return 301 https://\$host\$request_uri;
}
EOF
)
##########
wp_https_conf=$(cat << EOF
\$_SERVER['REQUEST_URI'] = str_replace("/wp-admin/", "/wordpress/wp-admin/",  \$_SERVER['REQUEST_URI']);

if ( \$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https' )
{
        \$_SERVER['HTTPS']       = 'on';
    \$_SERVER['SERVER_PORT'] = '443';
        define('FORCE_SSL_ADMIN', true);
}

if ( isset(\$_SERVER['HTTP_X_FORWARDED_HOST']) )
{
        \$_SERVER['HTTP_HOST'] = \$_SERVER['HTTP_X_FORWARDED_HOST'];
}
EOF
)

#  sudo apt install apache2 \
#                  ghostscript \
#                  libapache2-mod-php \
#                  mysql-server \
#                  php \
#                  php-bcmath \
#                  php-curl \
#                  php-imagick \
#                  php-intl \
#                  php-json \
#                  php-mbstring \
#                  php-mysql \
#                  php-xml \
#                  php-zip \
#                  expect \
#                  nginx -y

function install_mysql {
sudo systemctl start mysql.service
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$wp_root_password';"
expect << EOF
set timeout -1
spawn sudo mysql_secure_installation
match_max 100000
expect -exact "\r
Securing the MySQL server deployment.\r
\r
Enter password for user root: "
send -- "$wp_root_password\r"
expect -exact "\r
\r
VALIDATE PASSWORD COMPONENT can be used to test passwords\r
and improve security. It checks the strength of password\r
and allows the users to set only those passwords which are\r
secure enough. Would you like to setup VALIDATE PASSWORD component?\r
\r
Press y|Y for Yes, any other key for No: "
send -- "n\r"
expect -exact "n\r
Using existing password for root.\r
Change the password for root ? ((Press y|Y for Yes, any other key for No) : "
send -- "n\r"
expect -exact "n\r
\r
 ... skipping.\r
By default, a MySQL installation has an anonymous user,\r
allowing anyone to log into MySQL without having to have\r
a user account created for them. This is intended only for\r
testing, and to make the installation go a bit smoother.\r
You should remove them before moving into a production\r
environment.\r
\r
Remove anonymous users? (Press y|Y for Yes, any other key for No) : "
send -- "y\r"
expect -exact "y\r
Success.\r
\r
\r
Normally, root should only be allowed to connect from\r
'localhost'. This ensures that someone cannot guess at\r
the root password from the network.\r
\r
Disallow root login remotely? (Press y|Y for Yes, any other key for No) : "
send -- "n\r"
expect -exact "n\r
\r
 ... skipping.\r
By default, MySQL comes with a database named 'test' that\r
anyone can access. This is also intended only for testing,\r
and should be removed before moving into a production\r
environment.\r
\r
\r
Remove test database and access to it? (Press y|Y for Yes, any other key for No) : "
send -- "y\r"
expect -exact "y\r
 - Dropping test database...\r
Success.\r
\r
 - Removing privileges on test database...\r
Success.\r
\r
Reloading the privilege tables will ensure that all changes\r
made so far will take effect immediately.\r
\r
Reload privilege tables now? (Press y|Y for Yes, any other key for No) : "
send -- "y\r"
expect eof
EOF
sudo mysql -u root -p"$wp_root_password" -e "CREATE DATABASE $wp_dataname DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
sudo mysql -u root -p"$wp_root_password" -e "CREATE USER '$wp_datauser'@'%' IDENTIFIED WITH mysql_native_password BY '$wp_datapassword';"
sudo mysql -u root -p"$wp_root_password" -e "GRANT ALL ON $wp_dataname.* TO '$wp_datauser'@'%';"
sudo mysql -u root -p"$wp_root_password"-e "FLUSH PRIVILEGES;"
}

function install_wordpress {
if [ ! -d "$path_wp/wordpress" ]; then
curl -o /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz
tar -xvf /tmp/wordpress.tar.gz -C $path_wp
cp $path_wp/wordpress/wp-config-sample.php $path_wp/wordpress/wp-config.php
mkdir $path_wp/wordpress/wp-content/upgrade
sudo chown -R www-data:www-data $path_wp/wordpress
sudo find $path_wp/wordpress/ -type d -exec chmod 750 {} \;
sudo find $path_wp/wordpress/ -type f -exec chmod 640 {} \;
else echo "the directory wordpress exists"
fi
}

function change {

text="$1"
change_text="$2"
path_file="$3"
sudo sed -i "s/$text/$change_text/" "$path_file"
}

function create_line_wp {
add_text="$1"
path_file="$2"
if grep -qF "HTTP_X_FORWARDED_PROTO" "$path_file"; then
echo "https wordpres ready"
else
echo "$add_text" > temp.txt
sed -i '1r temp.txt' $path_file
sudo rm temp.txt  
fi
}

# install_mysql
# install_wordpress
# change "database_name_here" "$wp_dataname" "$path_wp/wordpress/wp-config.php"
# change "username_here" "$wp_datauser" "$path_wp/wordpress/wp-config.php"
# change "password_here" "$wp_datapassword" "$path_wp/wordpress/wp-config.php"
# create_line_wp "$wp_https_conf" "$path_wp/wordpress/wp-config.php"

# change "Listen 80" "Listen 8080" "$apache_path/ports.conf"
# change "\*:80>" "\*:8080" "/etc/apache2/sites-available/000-default.conf"
# change "\/var\/www\/html" "\/var\/www\/wordpress" "/etc/apache2/sites-available/000-default.conf"
# sudo systemctl restart apache2
# create_line_wp "$nginx_conf" "$nginx_path/sites-available/default"

if [ "$nginx_conf" != "$nginx_content" ]; then
sudo echo "$nginx_conf" > /etc/nginx/sites-available/default
else
echo "Содержимое переменной совпадает с содержимым файла"
fi

if ! [ -d "$nginx_path/ssl" ]; then
sudo mkdir "$nginx_path/ssl"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt
else
echo "сертфы готовы"
fi