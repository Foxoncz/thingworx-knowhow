# ThingWorx CentOs installation guide

Installation guide for ThingWorx 7 on CentOs 7, which is cummunity maintained fork of RedHat Enterprise Linux. For details, see [this post](http://unix.stackexchange.com/questions/27323/is-centos-exactly-the-same-as-rhel).

For ThingWorx official documentation reffer to:

- [ThingWorx_Core_7.2_System_Requirements_1.pdf](http://support.ptc.com/WCMS/files/171020/en/ThingWorx_Core_7.2_System_Requirements_1.pdf)
- [Installing_ThingWorx_7.2_1.pdf](http://support.ptc.com/WCMS/files/171019/en/Installing_ThingWorx_7.2_1.pdf)

Essentialy minimal required software version are:

- Oracle JDK 1.8
- Tomcat 8
- PostgreSQL 9

## STEP 1: Install CentOs

- Download CentOs DVD ISO from [centos.org](https://www.centos.org/download/).
- During installation select:

    - Date and Time: Set correct time and timezone.
    - Security: Standard Security Policy
    - Software Selection: Basic Web Server and you can consider Additional Guest Agents, if you running virtual machine.
    - (Optional) Network & Hostname: Set hostname to thingworx.example.com and configure static IP.

*Note: This ensures that you have minimal set up with SSH server and SE Linux activated.*

## STEP 2: Setup static IP (Optional)

All network configuration files are located in files bellow:

```
sudo cat /etc/sysconfig/network-scripts/ifcfg-xxx
sudo cat /etc/sysconfig/network
sudo cat /etc/resolv.conf
```
*Note: eth0 (xxx) is name of your interface, apended to file name, to see interfaces, run `ip addr`.*

For `eth0`, you need to modify `/etc/sysconfig/network-scripts/ifcfg-eth0`:

```
sudo vi /etc/sysconfig/network-scripts/ifcfg-eth0
```

Then change add or change theese values and save:

```
BOOTPROTO=static
ONBOOT=yes
IPADDR=172.16.16.54
NETMASK=255.255.255.0
GATEWAY=172.16.16.1
DNS1=172.16.24.1
DNS2=8.8.8.8
```

After that restart networking:

```
sudo systemctl restart network
```

To check new ip address run:

```
sudo ip addr
```

## Step 3: Install Java

Oracle JDK is recomended but you can also use OpenJDK, but it does not work correctly with HTTPS. That does not matter in case you want to use Apache or Nginx as frotnend for Tomcat anyway. It is recommended practice because of faster implementation of security features.

*Note: Clean CentOS installation does not have any network setting, if you did not set static ip in previous step, execute `dhclient` to start DHCP client and obtain new network settings from DHCP server. This can be automaticly started by setting it during installation or in interface file.*

To install latest Oracle JDK 1.8, visit [Oracle](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html) and change values to latest download file in following commands:

```
cd ~
wget --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u112-b15/jdk-8u112-linux-x64.rpm
yum localinstall jdk-8u112-linux-x64.rpm
```

To check current version:

```
sudo java -version
```

To switch active version:

```
sudo alternatives --config java
```

Oracle JDK is located in `/usr/java/latest` and if you install OpenJDK with `sudo yum install java-1.8.0-openjdk` instead, it is in `/usr/lib/jvm/jre`. 

*For detailed Oracle Java installation, please see: [https://www.digitalocean.com/community/tutorials/how-to-install-java-on-centos-and-fedora](https://www.digitalocean.com/community/tutorials/how-to-install-java-on-centos-and-fedora) or [https://www.mkyong.com/java/how-to-install-oracle-jdk-8-on-centos/](https://www.mkyong.com/java/how-to-install-oracle-jdk-8-on-centos/).*

## Step 4: Install PostgreSQL
In case the database is on separate machine, only next two steps are neccesary to set up ThingWorx database. But if this is the case, `platform-settings.json` file in `ThingworxPlatform` folder needs to reflect that.

There are some helpful guides to read first:

 - [PostgreSQL official guide](https://www.postgresql.org/download/linux/redhat/)
 - [Setup guide from Digital Ocean](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-postgresql-on-centos-7)

### Install PostgreSQL and setup Thingworx database

To get started, add this repository to yum:

```
sudo yum install http://yum.postgresql.org/9.5/redhat/rhel-7-x86_64/pgdg-redhat95-9.5-2.noarch.rpm
```

Then install required packages:

```
sudo yum install postgresql95-server postgresql95-contrib
```

PostgreSQL is installed to `/usr/pgsql-9.5/` from there you need to init db like this:

```
sudo /usr/pgsql-9.5/bin/postgresql95-setup initdb
```

### Edit configuration files


By default, PostgreSQL does not allow password authentication or network access (not neccesary if you running PostgreSQL on same machine). We will change that in next few steps.

Lets start with password authentification:

```
sudo vi /var/lib/pgsql/9.5/data/pg_hba.conf
```

In this file, you need to change `ident` to `md5` to allow password authentification and whitelist allowed ip on desired protocol, in our case `IPv4` to `all`.

```
# Original file

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            ident
# IPv6 local connections:
host    all             all             ::1/128                 ident

# Edited file

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             all                     md5
# IPv6 local connections:
host    all             all             ::1/128                 ident
```

You also need to allow PostgreSQL listening on network:

```
sudo vi /var/lib/pgsql/9.5/data/postgresql.conf
```

In this file, edit and uncomment theese values:

```
# Original file

#------------------------------------------------------------------------------
# CONNECTIONS AND AUTHENTICATION
#------------------------------------------------------------------------------

# - Connection Settings -

#listen_addresses = 'localhost'                 # what IP address(es) to listen on;
                                                # comma-separated list of addresses;
                                                # defaults to 'localhost'; use '*' for all
                                                # (change requires restart)
#port = 5432                                    # (change requires restart)

# Edited file

#------------------------------------------------------------------------------
# CONNECTIONS AND AUTHENTICATION
#------------------------------------------------------------------------------

# - Connection Settings -

listen_addresses = '*'                  # what IP address(es) to listen on;
                                        # comma-separated list of addresses;
                                        # defaults to 'localhost'; use '*' for all
                                        # (change requires restart)
port = 5432                             # (change requires restart)

```

*Note: This part is not neccessary if you running PostgreSQL on same machine, by default it accepts UNIX sockets.*

### Setup PostgreSQL as service

Then enable PostgreSQL to run as system service on startup via `systemd`:

```
sudo systemctl enable postgresql-9.5.service
sudo systemctl start postgresql-9.5.service
sudo systemctl status postgresql-9.5.service
```

### Change default user

For remote connection, we also need to change default PostgreSQL user password:

```
sudo -u postgres psql -c "ALTER ROLE postgres WITH password 'postgres'"
```

Now you should be able to connect from outside with pgAdmin. You may need to configure your firewall or simply take it down for testing with `systemctl stop firewalld.service`. On production environment, there should be firewall rule in place.

*Note: Settings above should whitelist only your trusted users, server ip addresses and protocols for optimal security, this depends on your specific configuration. Also please pick secure password for PostgreSQL default user and let system `postgres` user without password to enhance security. For more information, please read this stackoverflow [question](http://serverfault.com/questions/110154/whats-the-default-superuser-username-password-for-postgres-after-a-new-install). After you are done with ThingWorx database set up, you should even consider locking out default PostgreSQL user, please refer to [manual](https://www.postgresql.org/docs/9.1/static/auth-pg-hba-conf.html) for `pg_hba.conf` file.*

### Setup ThingWorx database
First, we need to create PostgreSQL user for ThingWorx. You can pick any username and password, but you need to also change it in `platform-settings.json` located at `ThingworxPlatform` folder later on.

To create new ThingWorx user run:

```
sudo -u postgres psql -c "CREATE USER twadmin WITH PASSWORD 'twadmin'"
```

As best practice, PostgreSQL database should be located on mounted storage drive out of the system drive. In desired location, we will create new folder and set access rigths:

```
sudo mkdir /ThingworxPostgresqlStorage
sudo chmod 775 /ThingworxPostgresqlStorage
sudo chown postgres:postgres /ThingworxPostgresqlStorage/ 
```

*Note: In some locations, you might run into SE Linux protection. It can be [disabled](https://www.centos.org/docs/5/html/5.2/Deployment_Guide/sec-sel-enable-disable-enforcement.html), but for security reasons it is recommended implement some exceptions. Please consult official [documentation](https://wiki.centos.org/HowTos/SELinux) and fine tune the settings for your specific use case.*

ThingWorx installation should be provided with database installation scripts, so copy ThingWorx install into your machine, `cd` into `install` directory and run:

```
sudo sh thingworxPostgresDBSetup.sh -a postgres -u twadmin -l /ThingworxPostgresqlStorage
sudo sh thingworxPostgresSchemaSetup.sh -u twadmin -o all
```

- `a` default PostgreSQL user or superuser with database creation rights
- `u` created ThingWorx user
- `l` path to directory with database 
- `o` create all aviable models

After this step, your database should be prepared for ThingWorx a if there is no firewall, you should be able to connect to it with pgAdmin.

## Step 5: Install Tomcat
CentoOs repository contains Tomcat version 7, but we will require at least version 8. That means little bit of extra work. There are some helpfull guides to get started:

- [How To Install Apache Tomcat 8 on CentOS 7](https://www.digitalocean.com/community/tutorials/how-to-install-apache-tomcat-8-on-centos-7)

 *Note: But note that before this step, you should already have JDK 1.8 installed from first step.*

### Create required groups and users

First, create a new `tomcat` group:

```
sudo groupadd tomcat
```

Then create a new `tomcat` user. We'll make this user a member of the `tomcat` group, with a home directory of `/opt/tomcat` (where we will install Tomcat), and with a shell of `/bin/false` (so nobody can log into the account):

```
sudo useradd -M -s /bin/nologin -g tomcat -d /usr/tomcat tomcat
```

### Download Tomcat
The easiest way to install Tomcat 8 at this time is to download the latest binary release then configure it manually.

First, change to your home directory:

```
cd ~
```

Find the latest version of Tomcat 8 at the [Tomcat 8 Downloads page](http://tomcat.apache.org/download-80.cgi). Then use `wget` and paste in the link to download the Tomcat 8 archive:

```
wget http://mirror.dkm.cz/apache/tomcat/tomcat-8/v8.5.8/bin/apache-tomcat-8.5.8.tar.gz
```

We're going to install Tomcat to the `/usr/tomcat` directory. Create the directory, then extract the the archive to it with these commands:

```
sudo mkdir /usr/tomcat
sudo tar xvf apache-tomcat-8*tar.gz -C /usr/tomcat --strip-components=1
```

Then make the `tomcat` owner of the directory:

```
sudo chown -R tomcat:tomcat /usr/tomcat
```

### Setup Systemd Unit File
Because we want to be able to run Tomcat as a service, we will set up a Tomcat `systemd` unit file.

Create and open the unit file by running this command:

```
sudo vi /usr/lib/systemd/system/tomcat.service
```

Paste in the following script:

```
[Unit]
Description=Apache Tomcat Web Application Container
After=syslog.target network.target

[Service]
Type=forking

Restart=on-failure

#Environment=JAVA_HOME=/usr/lib/jvm/jre #switch to OpenJdk
Environment=JAVA_HOME=/usr/java/latest
Environment=CATALINA_PID=/usr/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/usr/tomcat
Environment=CATALINA_BASE=/usr/tomcat
Environment='CATALINA_OPTS=-Xms1024M -Xmx1536M'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Dserver -Dd64'
Environment=THINGWORX_PLATFORM_SETTINGS=/ThingworxPlatform

ExecStart=/usr/tomcat/bin/startup.sh
ExecStop=/usr/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat

[Install]
WantedBy=multi-user.target
```

### Setup Tomcat as service

Then enable Tomcat to run as system service on startup via `systemd`:

```
sudo systemctl enable tomcat.service
sudo systemctl start tomcat.service
sudo systemctl status tomcat.service
```

Now you should be able go to `http://server_ip:8080/` and see Tomcat welcome page. You may need to configure your firewall or simply take it down for testing with systemctl stop firewalld.service. On production environment, there should be firewall rule in place.

### Configure ThingWorx

```
sudo mkdir /ThingworxStorage /ThingworxBackupStorage /ThingworxPlatform
sudo chown tomcat:tomcat /ThingworxStorage /ThingworxBackupStorage /ThingworxPlatform
sudo chmod 775 /ThingworxStorage /ThingworxBackupStorage /ThingworxPlatform
```

ThingWorx installation should be provided with `platform-settings.json`, open the file and modify content to required values and save it to your `ThingworxPlatform` directory.

```
{
   "PersistenceProviderPackageConfigs":{
      "PostgresPersistenceProviderPackage":{
         "ConnectionInformation":{
            "jdbcUrl":"jdbc:postgresql://localhost:5432/thingworx",
            "password":"twadmin",
            "username":"twadmin"
         }
      }
   },
   "PlatformSettingsConfig":{
      "BasicSettings":{
         "Storage":"/ThingworxStorage",
         "BackupStorage":"/ThingworxBackupStorage"
      }
   }
}
```

ThingWorx installation should be provided with `Thingworx.war` file, copy this file to `/usr/tomcat/webapps`. And then restart Tomcat with:

```
sudo systemctl restart tomcat.service
```

In your browser, open `http://server_ip:8080/Thingworx/Composer/index.html` and you should see Thingworx login screen. As credencials, use username `Administrator` with password `admin`. Note that it is strongly recomended to change default password and strip all permissions from default `Administrator` user.

## Step 8: Configure https
This step is not neccesary if you use Apache or Nginx as frontend and deal with ssl there. For some reason Tomcat HTTPS only works with redirection from `433` to internal `8433` via `firewalld`.

Generate selfsigned certificate as Java keystore file:

```
keytool -genkey -alias tomcat -keyalg RSA
```

Copy certificate from home to tomcat:

```
sudo cp ~/.keystore /usr/tomcat/conf/
sudo chown tomcat:tomcat /usr/tomcat/conf/.keystore
sudo chmod 640 /usr/tomcat/conf/.keystore
```

Edit default HTTP conector and add HTTPS connector to `server.xml` located in `/usr/tomcat/conf`:

```
<Connector port="8080" protocol="org.apache.coyote.http11.Http11NioProtocol"
            connectionTimeout="20000"
            redirectPort="8443" />

<Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"
            maxThreads="150" SSLEnabled="true" scheme="https" secure="true"
            clientAuth="false" sslProtocol="TLS"
            keystoreFile="/usr/tomcat/conf/.keystore" keystorePass="password"/>
```

## Step 7: Configure your firewall (Optional)
CentOs uses `firewalld` service and `firewall-cmd` for managment, for more complete guide see [https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-7](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-7).

Then enable firewall to run as system service on startup via `systemd`:

```
sudo systemctl enable firewalld.service
sudo systemctl start firewalld.service
sudo systemctl status firewalld.service
```

Check firewall state:

```
firewall-cmd --state
```

List all rules:

```
firewall-cmd --list-all
```

Forward expected ports to Tomcat internal ports:

```
firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080 --permanent
firewall-cmd --zone=public --add-forward-port=port=443:proto=tcp:toport=8443 --permanent
```

If you using static IP, you can safely remove rule for `DHCP` client:

```
sudo firewall-cmd --zone=public --remove-service=dhcpv6-client --permanent
```

Change `SSH` from port `22` to increase security:

```
sudo firewall-cmd --zone=public --remove-service=ssh
firewall-cmd --zone=public --add-forward-port=port=8022:proto=tcp:toport=22 --permanent
```

Reload firewall rules:

```
sudo firewall-cmd --reload
```

## Step 7: Configure network time sync (Optional)
Always having correct time is neccesary for many servers, in CentOS the default time sync service is `chrony`.

Start and enable `chronyd` deamon by running:

```
sudo systemctl enable chronyd.service
sudo systemctl start chronyd.service
sudo systemctl status chronyd.service
```