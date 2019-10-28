# ncbu


Once configured, this docker container automates backup of my nextcloud (data and database) and also provdides a simple way to restore from said backup.


## Configuration

This backup method is intended to be implemented with a docker-compose.yml file wherein containers are also configured for nextcloud and a database.  The ncbu container can be configured with the following definitions:
* networks:
	* a common network should be defined such that the ncbu container can interact with the nextcloud container.
* environment:
	* NEXTCLOUD_CONTAINER - The name given to the nextcloud container.  This is required.
	* NEXTCLOUD_DATABASE_CONTAINER - The namne given to the database container (such as mariadb or mysql).  Can be ommitted - data will still be backed up.
	* NEXTCLOUD_BACKUP_CRON - Cron-style config for setting when the backup script will be run.  Defaults to midnight daily (0 0 * * *) if ommitted.
* volumes:
	* /var/run/docker.sock - Must be bound to the host's equivalent to enable inter-container interaction.
	* /etc/localtime - Should be bound to the host's equivalent so that the cron job runs when expected.
	* /mnt/nextcloud_app - Must be bound to the same volume as the nextcloud container's data.
	* /mnt/nextcloud_db - Must be bound to the same volume as the database container's data.
	* /backup - Should be bound to a convenient user-accessible location.

The following example docker-compose.ynl file is configured so that the nextcloud and database (mariadb) containers use docker to manage their volumes.  The ncbu container (nextcloud-bu) will therefore sync both of these volumes to ./ncbu/nextcloud_app and ./ncbu/nextcloud_bu respectively.  The backup will occur every day at 0100hrs.

Notes:
* This example also uses letsencrypt and nginx-proxy containers for external https access.
* The nextcloud-cron container is used to periodically run nextcloud's cron.php script.
* Sensetive details can be entered directly into the *.yml or (as per this example) reference an external .env file (e.g. MARIADB_NEXTCLOUD_MYSQL_PASSWORD is defined in .env).
* The backups are stored at "./nextcloud-bu/". The intention is for this directory to be regularly synced off-site.


### docker-compose.yml
```
version: '3'  

services:

######################################### Nginx Proxy container
  nginx-proxy:
    image: jwilder/nginx-proxy:alpine
    container_name: nginx-proxy
    networks:
      - clews.pro_network
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
      - ./nginx-proxy/clews.pro_custom_proxy_settings.conf:/etc/nginx/conf.d/my_custom_proxy_settings.conf      #added to enable nc uploads>1MB (client_max_body_size 500m)
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/tmp/docker.sock:ro
    restart: unless-stopped

######################################### Let's Encrypt container
  letsencrypt:
    image: jrcs/letsencrypt-nginx-proxy-companion
    container_name: letsencrypt
    networks:
      - clews.pro_network
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
      - clews.pro_network
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
      - clews.pro_network
    depends_on:
      - letsencrypt
      - nginx-proxy
      - nextcloud-db
    environment:
      - VIRTUAL_HOST=nextcloud.clews.pro
      - LETSENCRYPT_HOST=nextcloud.clews.pro
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
    image: clewsy/ncbu
    container_name: nextcloud-bu
    networks:
      - clews.pro_network
    depends_on:
    - nextcloud-app
    - nextcloud-db
    environment:
    - NEXTCLOUD_CONTAINER=nextcloud-app                 # Name of the nextcloud container.
    - NEXTCLOUD_DATABASE_CONTAINER=nextcloud-db         # Name of the nextcloud database container.
    - NEXTCLOUD_BACKUP_CRON=0 0 * * *                   # Run at midnight.
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
  clews.pro_network:
```

## Manual backup
The backup script (ncbu.sh) can be run manually from within the container.  Alternatively, it can be run at any time with the following docker exec command:
```
$ docker exec nextcloud-bu ncbu.sh
```
If different, change "nextcloud-bu" to the appropriate container name.

## Restore from backup.
The process to restore nextcloud and the associated database from backups follows:
1. Set up the staging area.  This location should contain:
	* The docker-compose.yml file
	* The directory containing the backups (./nextcloud-bu in accordance with the example above).
2. Run docker-compose:
```
$ docker-compose up -d
```
3. Once running, initiate the ncbu_restore.sh script.  This may take some time.
```
$ docker exec nextcloud-bu ncbu_restore.sh
```
4. If the restoration is just to revert to an earlier snapshot then you should be done.  If the restoration was used to initialise nextcloud and the database on a clean system, then you may now need to bring the containers down then back up again with the newly restored database.  In this case you should run the restoration script again to exit from maintenance mode and run a file scan.
```
$ docker compose down
$ docker-compose up -d
$ docker exec nextcloud-bu ncbu_restore.sh
```
