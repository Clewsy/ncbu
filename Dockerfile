# Download base image: alpine linux.
FROM alpine:latest

# Update and install additional packages.
# bash		for running bash scripts.
# docker	for accessing the nextcloud container and enabling/disabling maintenance mode,
# rsync		for duplicating nextcloud data and database files.
RUN	apk update && \
	apk add bash && \
	apk add docker && \
	apk add rsync

# Define the environment variables:
# NEXTCLOUD_EXEC_USER=			The user for accessing the nextcloud container (to enable/disable maintenance mode). www-data by default.
# NEXTCLOUD_CONTAINER=			The container name for the nextcloud instance.
# NEXTCLOUD_DATABASE_CONTAINER=		The container name for the nextcloud database instance.
# NEXTCLOUD_BACKUP_CRON=		The crontab-style setting that defines when the backup script shall be run.  Midnight daily by default.
ENV	NEXTCLOUD_EXEC_USER=www-data \
	NEXTCLOUD_CONTAINER= \
	NEXTCLOUD_DATABASE_CONTAINER= \
	NEXTCLOUD_BACKUP_CRON="0 0 * * *"

# Create directories to be used within the container.
# /backup		This is the destination for the backup files.
# /mnt/nextcloud_app 	This is where the current nextcloud app data files will be mounted.
# /mnt/nextcloud_db 	This is where the current nextcloud database files will be mounted.
RUN mkdir -p	/backup \
		/mnt/nextcloud_app \
		/mnt/nextcloud_db

# Define the volumes for docker access.
# /mnt/nextcloud_app		The docker run command or docker-compose.yml file should mount the docker-managed nextcloud app volume to this
#				so that ncbu can access the current nextcloud data files.
# /mnt/nextcloud_db		The docker run command or docker-compose.yml file should mount the docker-managed nextcloud database volume to this
#				so that ncbu can access the current database files.
# /backup			This is where the "snapshot" backup will be stored, so the docker run command or docker-compose.yml should mount this
#				directory to a convenient user-accessible location.
VOLUME 	/mnt/nextcloud_app \
	/mnt/nextcloud_db \
	/backup

# Copy the backup scripts into the container  directory then add the root dir to PATH for convenience.
COPY ncbu_scripts/* /
ENV PATH=${PATH}:/

# Run the initialisation script.
ENTRYPOINT [ "ncbu_init.sh" ]

