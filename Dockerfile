# Download base image: alpine linux.
FROM alpine

# Define the environment variables:
#  NEXTCLOUD_EXEC_USER=			The user for accessing the nextcloud container. www-data by default.
#  NEXTCLOUD_CONTAINER=			The container name for the nextcloud instance.
#  NEXTCLOUD_DATABASE_CONTAINER=	The container name for the nextcloud database instance.
#  NEXTCLOUD_BACKUP_CRON=		The crontab-style setting to defines backup period.  Midnight daily by default.
#  PATH=				Set the root directory as a PATH location to easily execute custom scripts.
ENV	NEXTCLOUD_EXEC_USER=www-data \
	NEXTCLOUD_CONTAINER= \
	NEXTCLOUD_DATABASE_CONTAINER= \
	NEXTCLOUD_BACKUP_CRON="0 0 * * *" \
	PATH=${PATH}:/

# Update and install additional packages.
# bash :	for running bash scripts.
# docker-cli :	for running commands in other containers ("docker exec <CMD>").
# rsync :	for syncing nextcloud data and database files.
# logrotate :	for managing the $LOGFILE which can become large with rsync output.
RUN 	apk add --no-cache	bash \
				docker-cli \
				rsync \
				logrotate && \
# Create directories to be used within the container.
#  /backup :		This is the destination for the backup files.
#  /mnt/nextcloud_app :	This is where the live nextcloud app data files will be mounted.
#  /mnt/nextcloud_db : 	This is where the live nextcloud database files will be mounted.
	mkdir --parents	/backup \
			/mnt/nextcloud_app \
			/mnt/nextcloud_db
	
# Define the custom volumes.
#  /mnt/nextcloud_app :	The docker run command or docker-compose.yml file should mount the docker-managed nextcloud app volume to
#			this location so that ncbu can access the live nextcloud data files.
#  /mnt/nextcloud_db :	The docker run command or docker-compose.yml file should mount the docker-managed nextcloud database volume
#			to this location so that ncbu can access the live database files.
#  /backup		This is where the "snapshot" physical backup will be stored, so the docker run command or docker-compose.yml
#			should mount this directory to a convenient user-accessible location.  The log file is also here. 
VOLUME 	/mnt/nextcloud_app \
	/mnt/nextcloud_db \
	/backup

# Copy the scripts and config files into the container image.
COPY root/. /

# Define the healthcheck option - script is run every 10 minutes.
# Running the command "docker ps" will show the ncbu container as "healthy" or "unhealthy".
# An "unhealthy" status means that either the cron daemon "crond" is not running or the nextcloud app container is down/absent.
HEALTHCHECK --interval=10m --timeout=1m CMD [ "ncbu_healthcheck" ]

# Run the initialisation script.
CMD [ "ncbu_init" ]
