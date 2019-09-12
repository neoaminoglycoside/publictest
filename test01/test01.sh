#!bin/bash

###  Variables for test task ###

TIMEZONE=Asia/Tashkent
LOCALE=ru_RU.UTF-8
SSH_PORT=2498
SSH_ROOT_PERMIT=no
SERVICEACCOUNT=serviceuser
SERVICEACCOUNTUSEPASSWORD=true
PASSWORD=`openssl rand -base64 14`
HTTP_LOGIN=monit
HTTP_PASSWORD=tinom

if [[ $EUID -ne 0 ]]; then
	echo "Root Privileges Required" 
	exit 1
fi

echo "--timezone-- Current" `timedatectl | grep zone`
echo "--timezone-- Setting Time zone to $TIMEZONE"
if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
	timedatectl set-timezone $TIMEZONE
else 
	echo "[ERROR] --timezone-- There Is No Such Time zone, check your variables"
fi


echo "##############"
echo "--locale-- Current locale" `cat /etc/default/locale`
echo "--locale-- Trying to generate locale $LOCALE"
locale-gen $LOCALE > /tmp/locale_gen_result 2>&1
if cat /tmp/locale_gen_result | grep Error > /dev/null; then
	echo "[ERROR] --locale-- Something went wrong"
else
	update-locale LANG=$LOCALE
	echo "[OK] --locale-- Everything Is Ok"
fi


echo "##############"
echo "--ssh-- Makig backup of /etc/ssh/sshd_config"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

echo "--ssh-- Changing Permit Login to $SSH_ROOT_PERMIT"
sed -i "s/.*PermitRootLogin .*/PermitRootLogin $SSH_ROOT_PERMIT/g" /etc/ssh/sshd_config 

echo "--ssh-- Changing Ssh port to $SSH_PORT"
sed -i "s/.*Port .*/Port $SSH_PORT/g" /etc/ssh/sshd_config

echo "--ssh-- Trying to restart ssh server"
service ssh restart

if [[ `systemctl is-active ssh` == "active" ]]; then
	echo "[OK] --ssh-- Everything Is Ok"
else
	echo "[ERROR] --ssh-- Something went wrong, revert sshd_config from backup"
	cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
	service ssh restart
fi

echo "##############"
echo "--user-- Trying to create User $SERVICEACCOUNT"
if cat /etc/passwd | grep $SERVICEACCOUNT > /dev/null; then
	echo "[WARNING] --user-- User $SERVICEACCOUNT already created earlier"
else
	if [[ $SERVICEACCOUNTUSEPASSWORD == true ]]; then
		useradd -m -p $PASSWORD -s /bin/bash $SERVICEACCOUNT
		echo "[OK] --user-- User $SERVICEACCOUNT with Password $PASSWORD created"
	else
		useradd -s /usr/sbin/nologin $SERVICEACCOUNT
		echo "[OK] --user-- User $SERVICEACCOUNT without Password and Disabled Login created"
	fi
fi

echo "##############"
echo "--sudo-- Adding $SERVICEACCOUNT to sudoers"
if cat /etc/sudoers | grep $SERVICEACCOUNT > /dev/null; then
	sed -i "s/.*$SERVICEACCOUNT .*/$SERVICEACCOUNT ALL = NOPASSWD: \/bin\/systemctl restart \*,\/bin\/systemctl start \*,\/bin\/systemctl stop \*, \/usr\/sbin\/service \* restart,\/usr\/sbin\/service \* start,\/usr\/sbin\/service \* stop/g" /etc/sudoers
else
	echo "$SERVICEACCOUNT ALL = NOPASSWD: /bin/systemctl restart *,/bin/systemctl start *,/bin/systemctl stop *,/usr/sbin/service * restart,/usr/sbin/service * start,/usr/sbin/service * stop" >> /etc/sudoers
fi

echo "##############"
if netstat -nltp | grep nginx > /dev/null; then
	echo "[OK] --nginx-- Already installed"
	if which htpasswd | grep htpasswd > /dev/null; then
		echo "[OK] --nginx-- Passwd Alreade installed"
	else
		echo "--nginx-- Installing apache2-utils"
		apt install apache2-utils -y > /dev/null 2>&1
	fi
else	
	echo "--nginx-- Adding Stable PPA repository"
	add-apt-repository ppa:nginx/stable -y > /dev/null 2>&1
	echo "--nginx-- Getting nginx via apt"
	apt install nginx apache2-utils-y > /dev/null 2>&1
	echo "--nginx-- Adding Nginx to Runtime"
	update-rc.d nginx defaults
	echo "--nginx-- Trying to restart nginx"
	service nginx restart
	if [[ `systemctl is-active nginx` == "active" ]]; then
		echo "[OK] --nginx-- Everything Is Ok"
	else
        	echo "[ERROR] --nginx-- Something went wrong"
	fi
fi

echo "##############"
echo "--monit-- Install monit service"
apt install monit -y > /dev/null 2>&1
echo "--monit-- Check if httpd monit exists on 2812 port"
if netstat -nltp | grep 2812 > /dev/null; then
	echo "[OK] --monit-- Everything is OK"
else
cat <<EOT > /etc/monit/conf-enabled/httpd.conf
set httpd port 2812 and
use address localhost  # only accept connection from localhost
allow localhost        # allow localhost to connect to the server and
#allow admin:monit      # require user 'admin' with password 'monit'
EOT
	echo "--monit-- Trying to restart monit"
	service monit restart
	if [[ `systemctl is-active monit` == "active" ]]; then
        	echo "--monit-- Checking httpd monit on 2812 port"
		if netstat -nltp | grep 2812 > /dev/null; then
        		echo "[OK] --monit-- Everything is OK"
		else
        		echo "[ERROR] --monit-- Something went wrong"
		fi
	else
		echo "[ERROR] --monit-- Something went wrong"
	fi

fi

echo "##############"
echo "--nginx-conf-- config to monit"
if cat /etc/nginx/sites-enabled/default | grep monit > /dev/null; then
	echo "[OK] --nginx-conf-- Everithing is OK"
else
	echo "--nginx-conf-- Makig backup of /etc/nginx/sites-enabled/default"
        cp /etc/nginx/sites-enabled/default /tmp/default_prev.bk
cat /dev/stdin /etc/nginx/sites-enabled/default <<EOI >> /tmp/default.tmp
upstream monit {
       	server localhost:2812;
}


EOI
	mv /tmp/default.tmp /etc/nginx/sites-enabled/default
	htpasswd -b -c /etc/nginx/passwdfordefault  monit tinom
	sudo sed -i '/location \//,/}/c\location /\ {\n auth_basic "Monit Administation Area";\n auth_basic_user_file /etc/nginx/passwdfordefault; \n proxy_pass http://monit; \n }' /etc/nginx/sites-enabled/default
	echo "--nginx-conf-- Trying to force reload"
	if service nginx configtest; then
	        echo "[OK] --nginx-conf-- Everithing is OK"
		service nginx reload
	else
	        echo "[ERROR] --nginx-conf-- Something went wrong, reverting from backup"
	        mv /tmp/default_prev.bk /etc/nginx/sites-enabled/default

	fi

fi

