#!/bin/bash -x

set -e

if [[ ! -z "$1" ]]
then
    MYSQL_USER_PASSWORD=$1
fi

# Update APT repository
sudo apt update

# Install Java 8 with Zulu
sudo apt install -y openjdk-8-jre

# Check java version
java -version

# Install nginx
sudo apt install -y nginx

# Install MySQL
sudo apt install -y mysql-server-5.7

# MySQL DB setup
sudo mysql -u root -e "CREATE DATABASE openboxes default charset utf8;"
sudo mysql -u root -e "CREATE USER 'openboxes'@'localhost' IDENTIFIED BY 'openboxes'"
sudo mysql -u root -e "GRANT ALL on openboxes.* to openboxes@localhost IDENTIFIED BY '${MYSQL_USER_PASSWORD}';"

# Download OpenBoxes WAR
sudo mkdir -p /opt/openboxes/.grails
cd /opt/openboxes/
sudo wget --no-verbose https://bamboo-ci.pih-emr.org/browse/OPENBOXES-OBDEV3/latest/artifact/shared/Latest-WAR/openboxes.war

# Create Grails configuration file and move it to /opt/openboxes/.grails/
cat <<-EOT > /tmp/openboxes.yml
dataSource.dbCreate: none
dataSource.url: jdbc:mysql://localhost:3306/openboxes?useSSL=false
dataSource.username: openboxes
dataSource.password: ${MYSQL_USER_PASSWORD}
openboxes.jobs.calculateQuantityJob.cronExpression: "0 0 0 * * ?"
openboxes.anonymize.enabled: false
EOT

sudo mv /tmp/openboxes.yml /opt/openboxes/.grails/openboxes.yml

# Setup openboxes user and files access
sudo useradd --user-group --shell /bin/false  --home-dir /opt/openboxes openboxes
sudo chown -R openboxes:openboxes /opt/openboxes

# Installation OB as a systemd Service
sudo bash -c 'cat <<-EOT > /etc/systemd/system/openboxes.service
[Unit]
Description=OpenBoxes app
After=syslog.target

[Service]
User=openboxes
WorkingDirectory=/opt/openboxes
ExecStart=/usr/bin/java -Dgrails.env=prod -jar /opt/openboxes/openboxes.war
SuccessExitStatus=143
RestartSec=10
Restart=always

Environment="JAVA_TOOL_OPTIONS=-Xms1024m -Xmx1024m -XX:+UseParallelGC -Djava.awt.headless=true"

[Install]
WantedBy=multi-user.target
EOT'

sudo systemctl daemon-reload
sudo systemctl enable openboxes

# Run openboxes service
sudo service openboxes start

# Create Nginx reverse proxy configuration
sudo bash -c 'cat <<-EOT > /etc/nginx/sites-available/reverse-proxy.conf
server {
    listen 80;

    access_log /var/log/nginx/reverse-access.log;
    error_log /var/log/nginx/reverse-error.log;

    location / {
        proxy_set_header   X-Forwarded-For /$remote_addr;
        proxy_pass         "http://127.0.0.1:8080";
    }
}
EOT'

# Enable Nginx reverse proxy configuration
sudo unlink /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/reverse-proxy.conf /etc/nginx/sites-enabled/reverse-proxy.conf
sudo service nginx restart
