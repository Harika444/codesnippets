#!/bin/bash -x

echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 1.0.0.1" >> /etc/resolv.conf
yum update -y
yum install -y wget git vim
wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
yum install -y jenkins java

service jenkins start
chkconfig jenkins on

##########  It needs to settle  ###########
sleep 15
service jenkins restart
#########   It needs to settle again to finish making all it's directories  #########
sleep 20

sed -i 's/NEW/RUNNING/' /var/lib/jenkins/config.xml
rm -f /var/lib/jenkins/secrets/initialAdminPassword

echo "1c1c98f5dc4c173228b0a6cada2f408c2a140e97c0d58c30245e011f577bf9c19331a3d47b3a8ce2a871d74c844ffedd25c220abd17ffd3c2332593e48756dd34b2931d053fbd9cc8d785bc20a38fcb7b9818895869211788576751291e2065ceb81035fe87289dc69e7c95f078f11dd5dfe4b95d9011c6fcc85e28e7b18c8ca" > /var/lib/jenkins/secrets/master.key
chmod 644 /var/lib/jenkins/secrets/master.key

echo "<?xml version='1.1' encoding='UTF-8'?>
<hudson.model.UserIdMapper>
  <version>1</version>
  <idToDirectoryNameMap class=\"concurrent-hash-map\">
    <entry>
      <string>admin</string>
      <string>admin_8070509556156382097</string>
    </entry>
  </idToDirectoryNameMap>
</hudson.model.UserIdMapper>" > /var/lib/jenkins/users/users.xml

chmod 644 /var/lib/jenkins/users/users.xml

rm -rf /var/lib/jenkins/users/admin*

mkdir /var/lib/jenkins/users/admin_8070509556156382097 

echo "<?xml version='1.1' encoding='UTF-8'?>
<user>
  <version>10</version>
  <id>admin</id>
  <fullName>admin</fullName>
  <description></description>
  <properties>
    <jenkins.security.ApiTokenProperty>
      <tokenStore>
        <tokenList/>
      </tokenStore>
    </jenkins.security.ApiTokenProperty>
    <jenkins.security.LastGrantedAuthoritiesProperty>
      <roles>
        <string>authenticated</string>
      </roles>
      <timestamp>1595278970522</timestamp>
    </jenkins.security.LastGrantedAuthoritiesProperty>
    <hudson.model.MyViewsProperty>
      <primaryViewName></primaryViewName>
      <views>
        <hudson.model.AllView>
          <owner class=\"hudson.model.MyViewsProperty\" reference=\"../../..\"/>
          <name>all</name>
          <filterExecutors>false</filterExecutors>
          <filterQueue>false</filterQueue>
          <properties class=\"hudson.model.View\$PropertyList\"/>
        </hudson.model.AllView>
      </views>
    </hudson.model.MyViewsProperty>
    <hudson.model.PaneStatusProperties>
      <collapsed/>
    </hudson.model.PaneStatusProperties>
    <hudson.security.HudsonPrivateSecurityRealm_-Details>
      <passwordHash>#jbcrypt:\$2a\$10\$hdpPDuBVGALjoqqb/W/SGe5Fv7pHxnLjFpxKLmmzFNzTaH3oWWwGW</passwordHash>
    </hudson.security.HudsonPrivateSecurityRealm_-Details>
    <org.jenkinsci.main.modules.cli.auth.ssh.UserPropertyImpl>
      <authorizedKeys></authorizedKeys>
    </org.jenkinsci.main.modules.cli.auth.ssh.UserPropertyImpl>
    <jenkins.security.seed.UserSeedProperty>
      <seed>62f0ede324d4f76b</seed>
    </jenkins.security.seed.UserSeedProperty>
    <hudson.search.UserSearchProperty>
      <insensitiveSearch>true</insensitiveSearch>
    </hudson.search.UserSearchProperty>
    <hudson.model.TimeZoneProperty>
      <timeZoneName></timeZoneName>
    </hudson.model.TimeZoneProperty>
  </properties>
</user>" > /var/lib/jenkins/users/admin_8070509556156382097/config.xml

chmod 644 /var/lib/jenkins/users/admin_8070509556156382097/config.xml

chown -R jenkins:jenkins /var/lib/jenkins/
service jenkins restart

echo "US
NJ
Englewood
NBCU
NCX
Jenkins
admin@noreply.com" > cert.deff

IP=`ip a | grep inet | grep -v 127.0.0 | grep -v inet6 | awk '{print $2}' | cut -f1 -d"/" `

sleep 2

yum localinstall http://nginx.org/packages/rhel/7/noarch/RPMS/nginx-release-rhel-7-0.el7.ngx.noarch.rpm -y
mv /etc/yum.repos.d/nginx.repo.rpmnew /etc/yum.repos.d/nginx.repo

yum clean all
yum install -y nginx


echo "
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] \"\$request\" '
                      '\$status \$body_bytes_sent \"\$http_referer\" '
                      '\"\$http_user_agent\" \"\$http_x_forwarded_for\"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;
    include /etc/nginx/conf.d/*.conf;
    ## add ssl entries when https has been set in config
    ssl_certificate           /etc/nginx/cert.crt;
    ssl_certificate_key       /etc/nginx/cert.key;
    #ssl_session_cache shared:SSL:1m;
    #ssl_prefer_server_ciphers   on;

    server {

        listen 443;
        server_name $IP;
        if (\$http_x_forwarded_proto = '') {
            set \$http_x_forwarded_proto  \$scheme;
        }

    ssl on;
    ssl_session_cache  builtin:1000  shared:SSL:10m;
    ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
    ssl_prefer_server_ciphers on;

    access_log            /var/log/nginx/jenkins.access.log;

    location / {

      proxy_set_header        Host \$host;
      proxy_set_header        X-Real-IP \$remote_addr;
      proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header        X-Forwarded-Proto \$scheme;

      # Fix the \“It appears that your reverse proxy set up is broken\" error.
      proxy_pass          http://localhost:8080;
      proxy_read_timeout  90;
      proxy_redirect      http://localhost:8080 https://$IP;
    }
  }
}
" > /etc/nginx/nginx.conf


openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/cert.key -out /etc/nginx/cert.crt < cert.deff
sleep 5

#####################################################################################
##############  Plugins  ############################################################
#####################################################################################
####  /var/lib/jenkins/plugins/ folder has CVE riddled plugins and needs fixing  ####
######################    These need to be removed    ###############################
rm -f /var/lib/jenkins/plugins/*
#####################################################################################

mkdir PLUGINS

echo "nexus-jenkins-plugin
bouncycastle-api
command-launcher
external-monitor-job
jdk-tool
matrix-auth
matrix-project
pam-auth
script-security
windows-slaves
workflow-api
plain-credentials
token-macro
workflow-step-api
credentials
git
ssh-credentials
git-client
scm-api
mailer
workflow-scm-step
sonarqube-generic-coverage
code-coverage-api
trilead-api
display-url-api
jsch
apache-httpcomponents-client-4-api
jackson2-api
branch-api
cloudbees-folder
snakeyaml-api
maven-plugin
deployed-on-column
javadoc
junit
ldap
htmlpublisher
script-security
antisamy-markup-formatter
deployer-framework
structs" > PLUGINS/LIST

cd PLUGINS

while read LINE
  do
    wget https://updates.jenkins-ci.org/latest/$LINE.hpi
done < LIST

mv *.hpi /var/lib/jenkins/plugins/.
chown -R jenkins:jenkins /var/lib/jenkins/plugins
cd .. && rm -rf PLUGINS

chown -R nginx:nginx /etc/nginx
service jenkins restart
service nginx restart
setsebool -P httpd_can_network_connect 1

