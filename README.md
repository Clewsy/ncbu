# ncbu

Once configured, this docker container automates backup of a nextcloud instance (data and database) and also provdides a simple way to restore from said backup.

## Build the Container Image

The following commands will build the container image on the local host (assuming git and docker are installed):
```bash
$ git clone https://gitlab.com/clewsy/ncbu
$ cd ncbu
$ docker build -t registry.gitlab.com/clewsy/ncbu .
```

Or the image can be pulled directly from the GitLab container registry:
```bash
$ docker pull registry.gitlab.com/clewsy/ncbu
```

The GitLab container registry is recommended, but alternatively the image can be pulled directly from dockerhub:
```bash
$ docker pull clewsy/ncbu
```

## Configuration

The container can be created fom the command line, for example:
```bash
$ docker run \
	--name nextcloud-bu \
	--env NEXTCLOUD_CONTAINER=nextcloud \
	--env NEXTCLOUD_DATABASE_CONTAINER=nextcloud-db \
	--env NEXTCLOUD_BACKUP_CRON="0 0 * * *" \
	--volume /etc/localtime:/etc/localtime:ro \
	--volume /var/run/docker.sock:/var/run/docker.sock:ro \
	--volume nextcloud-app:/mnt/nextcloud-app \
	--volume nextcloud-db:/mnt/nextcloud-db \
	--volume /home/docker/nextcloud-bu:/backup \
	--detach \
	registry.gitlab.com/clewsy/ncbu
```

However, this backup method is intended to be implemented with a **docker-compose.yml** file within which additional containers are configured for nextcloud and a database.  The ncbu container can be configured with the following parameters:
* environment:
	* **NEXTCLOUD_EXEC_USER** - The user ID with permission to access data and run the occ command within the nextcloud container.  By default this is **www-data**.
	* **NEXTCLOUD_CONTAINER** - The name given to the nextcloud container.  This is required.
	* **NEXTCLOUD_DATABASE_CONTAINER** - The name given to the database container (such as mariadb or mysql).  Can be ommitted (data will still be backed up).
	* **NEXTCLOUD_BACKUP_CRON** - Cron-style config for setting when the backup script will be run.  Defaults to midnight daily (0 0 * * *) if ommitted.
* volumes:
	* **/var/run/docker.sock** - Must be bound to the host's equivalent to enable interaction with other containers.
	* **/etc/localtime** - Should be bound to the host's equivalent so that the cron job runs when expected (syncs container date/time to host date/time).
	* **/mnt/nextcloud_app** - Must be bound to the same volume as the nextcloud container's data.
	* **/mnt/nextcloud_db** - Optional.  To back up the database files, this must be bound to the same volume as the database container's data.
	* **/backup** - Should be bound to a convenient user-accessible location.

The following example **docker-compose.yml** file is configured in such a way that the nextcloud and database (mariadb) containers use docker to manage their volumes.  The ncbu container (**nextcloud-bu**) will therefore sync both of these Docker-managed volumes to **./nextcloud-bu/nextcloud_app** and **./nextcloud-bu/nextcloud_db** respectively.  The backup in this example will occur every day at 0100hrs.

Notes:
* This example also uses [nginx-proxy][link_dockerhub_nginx_proxy] and [acme-companion][link_dockerhub_nginx_proxy_acme_companion] containers for external https access.
* The [nextcloud-cronjob][link_dockerhub_rcdailey_nextcloud-cronjob] container is used to periodically run nextcloud's cron.php script.
* Sensitive details/credentials can be entered directly into the **docker-compose.yml** file, or (as per this example) reference an external **.env** file.  For example, the password for the nextcloud MariaDB database is defined in **.env** by a line: **MARIADB_NEXTCLOUD_MYSQL_PASSWORD=secure_password**.
* The backups are stored at **./nextcloud-bu/**. The intention is for this directory to be regularly synced off-site.
* You may encounter difficulty syncing the database files should you use the official MariaDB docker image.  Issues arise if the UID and GID of the user within the database container do not match the host user.  To avoid this, I recommend using the [mariadb docker image][link_dockerhub_linuxserver_mariadb] created by [linuxserver.io][link_web_linuxserver] (as per example below) wherein you can specify the UID and GID.
* Similarly to the note above, be sure to confirm read access to all the files created by an ncbu backup.  If, for example, the backup is being synced off-site, the user duplicating the backup may not have read access by default for files owned by user **www-data**.  In this example, adding the user to the **www-data** group may be sufficient to enable read access.
* Syncs can be confirmed and issues can be debugged by viewing the ncbu.log logfile.  This will be located in the directory to which **/backup** is bound.  In the example below the log file can be viewed from the host system with the command: `$ cat ./nextcloud-bu/ncbu.log`.
* The GitLab container registry is the recommended image source for ncbu due to dockerhub changes making maintenance less streamlined.  However, the image will probably also be current if pulled directly from docker hub.  Just substitute **registry.gitlab.com/clewsy/ncbu** in the .yml file with **clewsy/ncbu**. 

### docker-compose.yml
```yml
version: '3'  

services:

######################################### Nginx-proxy container
  nginx-proxy:
    image: nginxproxy/nginx-proxy:alpine
    container_name: nginx-proxy
    networks:
      - your.site_network
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./nginx-proxy/conf.d:/etc/nginx/conf.d:rw
      - ./nginx-proxy/vhost.d:/etc/nginx/vhost.d
      - ./nginx-proxy/html:/usr/share/nginx/html
      - ./nginx-proxy/dhparam:/etc/nginx/dhparam
      - ./nginx-proxy/certs:/etc/nginx/certs:ro
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped

######################################### Nginx-proxy-acme-companion container
  nginx-proxy-acme:
    image: nginxproxy/acme-companion
    container_name: nginx-proxy-acme
    networks:
      - your.site_network
    depends_on:
      - nginx-proxy
    environment:
      - NGINX_PROXY_CONTAINER=nginx-proxy
    volumes:
      - ./nginx-proxy/vhost.d:/etc/nginx/vhost.d
      - ./nginx-proxy/html:/usr/share/nginx/html
      - ./nginx-proxy/certs:/etc/nginx/certs
      - ./nginx-proxy/acme.sh:/etc/acme.sh
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped

######################################### MariaDB database (for nextcloud) container
  nextcloud-db:
    image: linuxserver/mariadb
    container_name: nextcloud-db
    networks:
      - your.site_network
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
  nextcloud:
    image: nextcloud
    container_name: nextcloud
    networks:
      - your.site_network
    depends_on:
      - nginx-proxy
      - nginx-proxy-acme
      - nextcloud-db
    environment:
      - OVERWRITEPROTOCOL=https
      - VIRTUAL_PORT=80
      - VIRTUAL_HOST=${NEXTCLOUD_URL}
      - LETSENCRYPT_HOST=${NEXTCLOUD_URL}
      - LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
    volumes:
      - nextcloud-app:/var/www/html
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped

######################################### Nextcloud cronjob container (for periodically running cron.php)
  nextcloud-cron:
    image: rcdailey/nextcloud-cronjob
    container_name: nextcloud-cron
    network_mode: none
    depends_on:
      - nextcloud
    environment:
      - NEXTCLOUD_CONTAINER_NAME=nextcloud
      - NEXTCLOUD_CRON_MINUTE_INTERVAL=5
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped

######################################### Nextcloud backup container (for periodically copying data and database)
  nextcloud-bu:
    image: registry.gitlab.com/clewsy/ncbu
    container_name: nextcloud-bu
    network_mode: none
    depends_on:
      - nextcloud
      - nextcloud-db
    environment:
      - NEXTCLOUD_EXEC_USER=www-data                      # Name of the user that can execute the occ command in the nextcloud container (www-data by default).
      - NEXTCLOUD_CONTAINER=nextcloud                     # Name of the nextcloud container.
      - NEXTCLOUD_DATABASE_CONTAINER=nextcloud-db         # Name of the nextcloud database container.
      - NEXTCLOUD_BACKUP_CRON=0 0 * * *                   # Run at midnight.
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock         # Allows container to access another container.
      - /etc/localtime:/etc/localtime:ro                  # Use to sync time so that the crond runs as expected.
      - nextcloud-app:/mnt/nextcloud_app                  # Must match the docker-managed nextcloud app volume (/var/www/html).
      - nextcloud-db:/mnt/nextcloud_db                    # Must match the docker-managed nextcloud database volume (/var/lib/mysql).
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
The backup script ([ncbu][link_repo_ncbu]) can be run manually from within the container.  Alternatively, it can be run at any time with the following docker exec command:
```bash
$ docker exec nextcloud-bu ncbu
```
If different, change **nextcloud-bu** to the appropriate container name.

## Restore from Backup
The process to restore nextcloud and the associated database from backups used the restore script ([ncbu_restore][link_repo_ncbu_restore]) as follows:
1. Set up the staging directory.  This location should contain:
	* The **docker-compose.yml** file
	* The directory containing the backups (**./nextcloud-bu** in accordance with the example above).
2. Using docker-compose, run up the nextcloud app, database and ncbu containers:
```bash
$ docker-compose up -d
```
3. If the restoration is simply to revert to an earlier snapshot then continue to step 4.  If the restoration is to be used with a fresh nextcloud instance (e.g. migration to another host machine) then initialise the nextcloud instance and database with the same admin username and database configuration settings that were in use during the last backup.  In the example above these settings would be:
	* Configure the database: **MySQL/MariaDB**
	* Database user: **nextcloud**
	* Database password: **<MARIADB_NEXTCLOUD_MYSQL_PASSWORD>** (as defined within **.env**)
	* Database name: **nextcloud**
	* Database host: **nextcloud-db**
4. Initiate the **ncbu_restore** script.  This may take some time.  If an error occurs (**unable to enter maintenance mode**), ensure step three above was carried out correctly.
```bash
$ docker exec nextcloud-bu ncbu_restore
```
5. The restoration should be complete.  If any settings don't seem to be restored, bring the containers down and then restart them:
```bash
$ docker-compose down
$ docker-compose up -d
```

## Container Health
A healthcheck script ([ncbu_healthcheck][link_repo_ncbu_healthcheck]) is executed every ten minutes.  To determine the status/health of a running container, use the command:
```bash
$ docker ps
```
The output will include a **Status** column.  Here the ncbu contaioner should be noted as **healthy** if all is well.  An **unhealthy** status means one of two things:
1. The cron daemon (**crond**) is not running; or
2. The user defined nextcloud app container (**$NEXTCLOUD_CONTAINER**) is missing/not running.


## Logging
Output of the various scripts is logged to a file within the container's **/backup** directory.  The logfile will also include the verbose output from the rsync commands.

In the example yml file above, since the container's **/backup** directory is mapped to **./nextcloud-bu**, this is where the logfile can be read on the host machine.

The *ncbu* and *ncbu_restore* scripts also trigger the logrotate command.  The logfile will be rotated and archived if the file size exceeds 1M.  In this scenario the logfile can be viewed from the host machine by simply using the `cat` command.  Example logs shown below:
```bash
$ cat /home/docker/nextcloud-bu/ncbu.log

2021-06-18 00:00:00 - Running ncbu (nextcloud backup)...
2021-06-18 00:00:00 - Putting nextcloud into maintenance mode...
2021-06-18 00:00:00 - Nextcloud data backup: Syncing nextcloud volume to /backup...
2021/06/18 00:00:00 [35874] building file list
2021/06/18 00:00:01 [35874] >f..t...... config/config.php
2021/06/18 00:00:02 [35874] >f.st...... data/nextcloud.log
2021/06/18 00:00:02 [35874] >f.st...... data/appdata_oc037zsrujze/appstore/apps.json
2021/06/18 00:00:02 [35874] .d..t...... data/appdata_oc037zsrujze/preview/0/6/c/d/4/1/6/     

...

2021/06/18 00:00:06 [35874] sent 67.01M bytes  received 44.01K bytes  10.32M bytes/sec
2021/06/18 00:00:06 [35874] total size is 34.27G  speedup is 511.07
2021-06-18 00:00:06 - Finished nextcloud data sync.
2021-06-18 00:00:06 - Setting permission of nextcloud data directory to :33
2021-06-18 00:00:07 - Ensure user on host machine is part of group id GID=33 for read access to backup.
2021-06-18 00:00:07 - Nextcloud database backup (physical copy): Syncing nextcloud-db volume to /backup...
2021/06/18 00:00:07 [35901] building file list
2021/06/18 00:00:07 [35901] >f..t...... databases/ib_logfile0
2021/06/18 00:00:08 [35901] >f..t...... databases/ib_logfile1   

...

2021/06/18 00:00:10 [35901] >f.st...... log/mysql/mariadb-bin.index
2021/06/18 00:00:10 [35901] sent 386.56M bytes  received 436 bytes  110.45M bytes/sec
2021/06/18 00:00:10 [35901] total size is 878.59M  speedup is 2.27
2021-06-18 00:00:10 - Finished nextcloud database sync.
2021-06-18 00:00:10 - Taking nextcloud out of maintenance mode...
2021-06-18 00:00:10 - Rotating logfile if required...
2021-06-18 00:00:10 - All done. 
```


[link_dockerhub_linuxserver_mariadb]:https://hub.docker.com/r/linuxserver/mariadb
[link_dockerhub_nginx_proxy]:https://hub.docker.com/r/nginxproxy/nginx-proxy
[link_dockerhub_nginx_proxy_acme_companion]:https://hub.docker.com/r/nginxproxy/acme-companion
[link_dockerhub_rcdailey_nextcloud-cronjob]:https://hub.docker.com/r/rcdailey/nextcloud-cronjob
[link_repo_ncbu]:ncbu_scripts/ncbu
[link_repo_ncbu_healthcheck]:ncbu_scripts/ncbu_healthcheck
[link_repo_ncbu_restore]:ncbu_scripts/ncbu_restore
[link_web_linuxserver]:https://www.linuxserver.io/
