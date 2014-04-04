#!/bin/bash
#########################################################################################################################################
#
# Usage :  < path/to/script.sh >
# 	   eg: nginx.sh
#
# Description: This script will check if PHP, Mysql & Nginx are installed. If not present, missing packages will be installed
# 		1.The script will then ask user for domain name
#		2.It will configure it with a wordpress plugin
#
# Author        : Aswin Kumar TS
# Revision      : 2.0
# Creation      : Wednesday, April 02 2014
# Modification  : Friday, April 04 2014
 
#########################################################################################################################################
# GLOBAL VARIABLE SECTION
#########################################################################################################################################
PWD=`pwd`
NGINX_CONF=$PWD/example.conf
SCRIPT_USER=root
CURRENT_USER=`whoami`

#########################################################################################################################################
## Function to check for Required Packages
#########################################################################################################################################


package_check()
{

REQUIRED_PACKAGES='php5 php5-fpm nginx mysql-server'

read -p "Do you want to update repositories before installing - $packages [Y/n]: " VAR_B
if [ $VAR_B == "Y" ]
then
	echo " "
        echo "Executing apt-get update"
        apt-get update
        EXIT_STATUS=$?
        if [ $EXIT_STATUS -gt 0 ]
        then
        	echo " "
                echo "Error while udpating repositories,Please check network/repositories"
                exit 1
	fi
fi


for packages in `echo $REQUIRED_PACKAGES`
do
	echo "---------------------------------------------"
	dpkg-query -s $packages > /dev/null
	EXIT_STATUS=$?
	if [ $EXIT_STATUS -gt 0 ]
		then
			echo " "
			echo "Installing the Missing package:$packages"
			apt-get install $packages
			EXIT_STATUS=$?
			if [ $EXIT_STATUS -gt 0 ]
			then
				echo "Error while installing $packages,Please check network/repositories,Try the script again"
				exit 1
			fi
		else
			 echo "---------------------------------------------"
			 echo "$packages STATUS - OK"
	fi
			 
done

}

verify_installed_package()
{

ES_COUNT=0
for packages in `echo $REQUIRED_PACKAGES`
do
        echo "---------------------------------------------"
        dpkg-query -s $packages > /dev/null
        EXIT_STATUS=$?
	echo $packages && dpkg-query -W -f='${Status} ${Version}\n' $packages
        ES_COUNT=`expr $ES_COUNT + $EXIT_STATUS`
done
	if [ $ES_COUNT -gt 0 ]
	then
		echo "---------------------------------------------"
		echo "Some of the Required packages are not installed,So Terminating the script..."
		echo "---------------------------------------------"
		exit 1
	fi

}


#########################################################################################################################################
## Function to update Host entry to /etc/hosts
#########################################################################################################################################

host_entry()
{
echo " "
echo "Applying Host entry.."
grep ""$DOMAIN_NAME"$" /etc/hosts
EXIT_STATUS=$?
if [ $EXIT_STATUS -gt 0 ]
	then
		echo " "
		echo -e "$IP_ADDRESS	$DOMAIN_NAME" >> /etc/hosts
		grep ""$DOMAIN_NAME"$" /etc/hosts
		echo " "
	else
		echo " "
		echo "The above Host entry is present already for $DOMAIN_NAME"
		echo " "
		read -p "Are you sure want to add again [Y/n]: " VAR_E
		if [ "$VAR_E" == "Y" ]
		then
			echo -e "$IP_ADDRESS    $DOMAIN_NAME" >> /etc/hosts
		fi
		

fi
}

#########################################################################################################################################
## Function to download latest  wordpress plugins
#########################################################################################################################################

wordpress()
{
mkdir -p /var/www/$DOMAIN_NAME/htdocs/ /var/www/$DOMAIN_NAME/logs/
cd /var/www/$DOMAIN_NAME/htdocs/
wget http://wordpress.org/latest.tar.gz
tar --strip-components=1 -xvf latest.tar.gz
rm latest.tar.gz
cd
}

#########################################################################################################################################
## Function to configure domain name in nginx webserver
#########################################################################################################################################
nginx_conf()
{
if [ -d /etc/nginx/sites-available ]
then
	sed 's/example.com/'$DOMAIN_NAME'/g' $NGINX_CONF > /etc/nginx/sites-available/$DOMAIN_NAME
	ES=$?
	if [ $ES -gt 0 ]
		then
		echo "Error While copying $NGINX_CONF /etc/nginx/sites-available/$DOMAIN_NAME/."
		exit 1
	fi
	ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
	ln -s /var/log/nginx/$DOMAIN_NAME.access.log /var/www/$DOMAIN_NAME/logs/access.log
	ln -s /var/log/nginx/$DOMAIN_NAME.error.log /var/www/$DOMAIN_NAME/logs/error.log
	chown -R www-data:www-data /var/www/$DOMAIN_NAME/
	chown -R www-data:www-data /etc/nginx/sites-available
	echo " "
	nginx -t && service nginx restart || echo "Unable to restart nginx,Please check the configurations"
else
	echo "Directory :/etc/nginx/sites-available is not available"
	exit 1 
fi
}

#########################################################################################################################################
## Function for DB configuration
#########################################################################################################################################

db_conf()
{
echo " "
echo "Please Provide the DB details"
echo " "
read -p "Enter mysql username [root]: " DB_USER
echo " "
read -s -p "Enter mysql password : " DB_PASSWORD
echo " "
read -p "Enter Database name [ examplecomdb ]: " DB_NAME
echo " "
mysql -u $DB_USER -p$DB_PASSWORD -e 'create database '$DB_NAME''
DB_ES=$?
if [ $DB_ES -gt 0 ]
	then
		echo "Error: While creating database $DB_NAME"
fi
}

#########################################################################################################################################

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Nginx Installation/Configuration Started"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Checking for the script owner..."

if [ "$CURRENT_USER" != "$SCRIPT_USER" ]
	then
		echo " "
		echo " You dont have previdelge to execute this script.Please execute as $SCRIPT_USER"
		exit 1
fi


#########################################################################################################################################
## Main Function
#########################################################################################################################################

package_check
verify_installed_package
VAR_C=0
while [ "$VAR_C" != "" ]
	do
		echo " "
		read -p "Enter a domain name that you want to configure: " DOMAIN_NAME
		echo " "
		read -p "Press [Enter] Key to go with $DOMAIN_NAME,Type [N] to cancel: " VAR_C
		echo " "
	done
	IP_ADDRESS=`/sbin/ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1`
	read -p "Press [Enter] Key to go with "$IP_ADDRESS",Type [N] to cancel: " VAR_D
	echo " "
	if [ "$VAR_D" = "N" ]
		then
			read -p "Enter your IP ADDRESS manually: " IP_ADDRESS
			host_entry
	fi
	host_entry
	wordpress
	nginx_conf
	while [ "$DB_ES" != 0 ]
	do
	db_conf
	service nginx restart
	ES=$?
	if [ "$ES" -gt 0 ]
	then
        	echo "Error While restarting nginx, Please try manually once!"
		echo " "
	else
		echo " "
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo " Nginx configuration done for $DOMAIN_NAME, Please load $DOMAIN_NAME in your webbrowser"
		echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
		echo " "
	fi
	done
		
#########################################################################################################################################

