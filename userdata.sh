#!/bin/bash

export HOME=/home/ec2-user

##Packages to be installed
packages=("httpd" "php" "mariadb*server" "git" "curl" "expect" "php8.2-mysqlnd" )

##Iterate over packages and install them if not installed.
for package in "${packages[@]}"; do
	if rpm -q "$package" &>/dev/null; then
		echo "$package it's already installed."
	else
		echo "Installing $package"
		sudo dnf install -y "$package"
	fi
done

##Services to be enabled and started
services=("httpd" "php-fpm" "mariadb")

##Iterate over services and starting them...
for service in "${services[@]}"; do
	echo "Starting $service and enabling..."
	sudo systemctl enable --now "$service" 
done

##Function to configure permissions for ec2-user and apache

permissions(){
	sudo usermod -a -G apache ec2-user
	sudo chown -R ec2-user:apache /var/www
	sudo chmod 2775 /var/www
	sudo find /var/www -type d -exec sudo chmod 2775 {} \;
	sudo find /var/www -type f -exec sudo chmod 0664 {} \;
}

permissions


##Configure mysql using expect

cat <<EOF > mysql_secure_install.sh
#!/usr/bin/expect

spawn sudo mysql_secure_installation

expect "Enter current password for root (enter for none):"
send "\r"

expect "Switch to unix_socket authentication"
send "n\r"

expect "Change the root password?"
send "y\r"

expect "New password:"
send "asd123\r"

expect "Re-enter new password:"
send "asd123\r"

expect "Remove anonymous users?"
send "y\r"

expect "Disallow root login remotely?"
send "y\r"

expect "Remove test database and access to it?"
send "y\r"

expect "Reload privilege tables now?"
send "y\r"
EOF

##Add execution privileges
sudo chmod +x mysql_secure_install.sh
##Execute previously created script with expect
sudo expect mysql_secure_install.sh


##DB creation

cat <<EOF > devopstravel.sql
CREATE DATABASE devopstravel;
CREATE USER 'codeuser'@'localhost' IDENTIFIED by 'codepass';
GRANT ALL PRIVILEGES ON *.* TO 'codeuser'@'localhost';
FLUSH PRIVILEGES; 
EOF

##Execute script
sudo mysql -u root < devopstravel.sql

##Clone repository

if [ -d $HOME/bootcamp-devops-2023 ];
then
	echo "Repository already exist"
else
git clone -b clase2-linux-bash --single-branch https://github.com/roxsross/bootcamp-devops-2023.git $HOME/bootcamp-devops-2023/
cp -r $HOME/bootcamp-devops-2023/app-295devops-travel/* /var/www/html
sudo mysql -u root < $HOME/bootcamp-devops-2023/app-295devops-travel/database/devopstravel.sql
sudo rm -rf $HOME/bootcamp-devops-2023/
sudo sed -i 's/""/"codepass"/g' /var/www/html/config.php

sudo sed -i 's/DirectoryIndex index.html/DirectoryIndex index.php/g' /etc/httpd/conf/httpd.conf
sudo sed -i 's/DirectoryIndex index.html/DirectoryIndex index.php/g' /etc/httpd/conf/httpd.conf
fi

sudo systemctl restart httpd
sudo systemctl restart mariadb