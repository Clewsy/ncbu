# ncbu

Once configured, this docker container automates backup of a nextcloud instance (data and database) and also provdides a simple way to restore from said backup.

## Build the Container Image

The following commands will build the container image on the local host (assuming git and docker are installed):
```
$ git clone git@gitlab.com:clewsy/ncbu
$ cd ncbu
$ docker build -t ncbu/ncbu .
```
Altenatively the image can be pulled directly from docker hub:
```
$ docker pull ncbu/ncbu
```

## Configuration

This backup method is intended to be implemented with a docker-compose.yml file wherein containers are also configured for nextcloud and a database.  The ncbu container can be configured with the following definitions:
* networks:
	* a common network should be defined such that the ncbu container can interact with the nextcloud container.
* environment:
	* NEXTCLOUD_CONTAINER - The name given to the nextcloud container.  This is required.
	* NEXTCLOUD_DATABASE_CONTAINER - The name given to the database container (such as mariadb or mysql).  Can be ommitted - data will still be backed up.
	* NEXTCLOUD_BACKUP_CRON - Cron-style config for setting when the backup script will be run.  Defaults to midnight daily (0 0 * * *) if ommitted.
* volumes:
	* /var/run/docker.sock - Must be bound to the host's equivalent to enable inter-container interaction.
	* /etc/localtime - Should be bound to the host's equivalent so that the cron job runs when expected.
	* /mnt/nextcloud_app - Must be bound to the same volume as the nextcloud container's data.
	* /mnt/nextcloud_db - Optional.  To back up the database files, this must be bound to the same volume as the database container's data.
	* /backup - Should be bound to a convenient user-accessible location.

The following example docker-compose.yml file is configured so that the nextcloud and database (mariadb) containers use docker to manage their volumes.  The ncbu container (nextcloud-bu) will therefore sync both of these volumes to ./nextcloud-bu/nextcloud_app and ./nextcloud-bu/nextcloud_db respectively.  The backup in this example will occur every day at 0100hrs.

Notes:
* This example also uses [letsencrypt-nginx-proxy-companion](https://hub.docker.com/r/jrcs/letsencrypt-nginx-proxy-companion) and [nginx-proxy](https://hub.docker.com/r/jwilder/nginx-proxy) containers for external https access.
* The [nextcloud-cronjob](https://hub.docker.com/r/rcdailey/nextcloud-cronjob) container is used to periodically run nextcloud's cron.php script.
* Sensitive details can be entered directly into the *.yml or (as per this example) reference an external .env file (e.g. the password for the nextcloud MariaDB database is defined in .env by a line: MARIADB_NEXTCLOUD_MYSQL_PASSWORD=secure_password )
* The backups are stored at "./nextcloud-bu/". The intention is for this directory to be regularly synced off-site.
* You may encounter difficulty syncing the database files should you use the official MariaDB docker image.  Issues arise if the UID and GID of the user within the database container do not match a user on the host.  To avoid this, I recommend using the mariadb docker image created by linuxserver.io (as per example below) wherein you can specify the UID and GID: [linuxserver.io mariadb image at docker hub](https://hub.docker.com/r/linuxserver/mariadb)
* Similarly to the note above, be sure to confirm read access to all the files created by an ncbu backup.  If, for example, the backup is being synced off-site, the user duplicating the backup may not have access by default to read files owned by user www-data.  In this example, adding the user to the www-data group may be sufficient to enable read access.

### docker-compose.yml
```
version: '3'  

services:

######################################### Nginx Proxy container
  nginx-proxy:
    image: jwilder/nginx-proxy:alpine
    container_name: nginx-proxy
    networks:
      - your.site_network
    labels:
      - "com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy=true"
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./nginx-proxy/conf.d:/etc/nginx/conf.d:rw
      - ./nginx-proxy/vhost.d:/etc/nginx/vhost.d:rw
      - ./nginx-proxy/html:/usr/share/nginx/html:rw
      - ./nginx-proxy/certs:/etc/nginx/certs:ro
      - ./nginx-proxy/your.site_custom_proxy_settings.conf:/etc/nginx/conf.d/my_custom_proxy_settings.conf      #added to enable nc uploads>1MB (client_max_body_size 500m)
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/tmp/docker.sock:ro
    restart: unless-stopped

######################################### Let's Encrypt container
  letsencrypt:
    image: jrcs/letsencrypt-nginx-proxy-companion
    container_name: letsencrypt
    networks:
      - your.site_network
    depends_on:
      - nginx-proxy
    volumes:
      - ./nginx-proxy/certs:/etc/nginx/certs:rw
      - ./nginx-proxy/vhost.d:/etc/nginx/vhost.d:rw
      - ./nginx-proxy/html:/usr/share/nginx/html:rw
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped

######################################### MariaDB database (for nextcloud) container
  nextcloud-db:
    image: linuxserver/mariadb
    container_name: nextcloud-db
    networks:
      - your.site_network
    ports:
      - 3306:3306
    environment:
      - PUID=1000
      - PGID=1000
      - MYSQL_ROOT_PASSWORD=${MARIADB_NEXTCLOUD_MYSQL_ROOT_PASSWORD}
      - MYSQL_USER=nextcloud
      - MYSQL_PASSWORD=${MARIADB_NEXTCLOUD_MYSQL_PASSWORD}
      - MYSQL_DATABASE=nextcloud
    volumes:
      - nextcloud-db:/config
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped

######################################### Nextcloud web app container
  nextcloud-app:
    image: nextcloud:latest
    container_name: nextcloud-app
    networks:
      - your.site_network
    depends_on:
      - letsencrypt
      - nginx-proxy
      - nextcloud-db
    environment:
      - VIRTUAL_HOST=nextcloud.your.site
      - LETSENCRYPT_HOST=nextcloud.your.site
      - LETSENCRYPT_EMAIL=${NEXTCLOUD_APP_LETSENCRYPT_EMAIL}  
    volumes:
      - nextcloud-app:/var/www/html
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped

######################################### Nextcloud cron container (for periodically running cron.php)
  nextcloud-cron:
    image: rcdailey/nextcloud-cronjob
    container_name: nextcloud-cron
    network_mode: none
    depends_on:
    - nextcloud-app
    environment:
    - NEXTCLOUD_CONTAINER_NAME=nextcloud-app
    - NEXTCLOUD_CRON_MINUTE_INTERVAL=5
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped

######################################### Nextcloud backup container (for periodic physical snapshots of data and database volumes)
  nextcloud-bu:
    image: ncbu/ncbu
    container_name: nextcloud-bu
    networks:
      - your.site.pro_network
    depends_on:
    - nextcloud-app
    - nextcloud-db
    environment:
    - NEXTCLOUD_CONTAINER=nextcloud-app                 # Name of the nextcloud container.
    - NEXTCLOUD_DATABASE_CONTAINER=nextcloud-db         # Name of the nextcloud database container.
    - NEXTCLOUD_BACKUP_CRON=0 1 * * *                   # Run daily at 0100hrs.
    volumes:
    - /var/run/docker.sock:/var/run/docker.sock         # Allows container to access another container.
    - /etc/localtime:/etc/localtime:ro                  # Use to sync time so that the crond runs as expected.
    - nextcloud-app:/mnt/nextcloud_app:ro               # Must match the docker-managed nextcloud app volume (/var/www/html).
    - nextcloud-db:/mnt/nextcloud_db:ro                 # Must match the docker-managed nextcloud database volume (/var/lib/mysql).
    - ./nextcloud-bu:/backup                            # Convenient location for the backup.
    restart: unless-stopped

######################################### Docker-managed volumes
volumes:
  nextcloud-app:
  nextcloud-db:

######################################### Docker-managed networks
networks:
  your.site_network:
```

## Manual Backup
The backup script (ncbu.sh) can be run manually from within the container.  Alternatively, it can be run at any time with the following docker exec command:
```
$ docker exec nextcloud-bu ncbu.sh
```
If different, change "nextcloud-bu" to the appropriate container name.

## Restore from Backup
The process to restore nextcloud and the associated database from backups follows:
1. Set up the staging directory.  This location should contain:
	* The docker-compose.yml file
	* The directory containing the backups (./nextcloud-bu in accordance with the example above).
2. Run docker-compose:
```
$ docker-compose up -d
```
3. If the restoration is simply to revert to an earlier snapshot then continue to step 4.  If the restoration is to be used with a fresh nextcloud instance (e.g. migration to another host machine) then initialise the nextcloud instance with the same admin username and database configuration settings that were present during the last backup.  In the example above these settings would be:
	* Configure the database: MySQL/MariaDB
	* Database user: nextcloud
	* Database password: <MARIADB_NEXTCLOUD_MYSQL_PASSWORD> (as defined within .env)
	* Database name: nextcloud
	* Database host: nextcloud-db
4. Initiate the ncbu_restore.sh script.  This may take some time.
```
$ docker exec nextcloud-bu ncbu_restore.sh
```
5. The restoration should be complete.  If any settings don't seem to be restored, bring the containers down and then restart them:
```
$ docker compose down
$ docker-compose up -d
```
