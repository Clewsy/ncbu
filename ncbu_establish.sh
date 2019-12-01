#! /bin/bash

## An example docker run usage for creating an ncbu container.

docker run -ti \
	-e NEXTCLOUD_CONTAINER=nextcloud-app \			#environment variable - define the nextcloud app name.
	-e NEXTCLOUD_DATABASE_CONTAINER=nextcloud-db \		#environment variable - define the nextcloud database name.
	-e NEXTCLOUD_BACKUP_CRON="0 0 * * *" \			#environment variable - define the cronjob interval for running the bckup script.
	-v /etc/localtime:/etc/localtime:ro \			#volume - link the local time to the ncbu container so the cron job runs when expected.
	-v /var/run/docker.sock:/var/run/docker.sock:ro \	#volume - link the docker.sock to enable docker commands to reach other containers.
	-v nextcloud-app:/mnt/nextcloud-app \			#volume - define the nextcloud app volume for mounting within the ncbu container.
	-v nextcloud-db:/mnt/nextcloud-db \			#volume - define the nextcloud database volume for mounting within the ncbu container.
	-v ./nextcloud-bu:/backup \				#volume - define the user-accessible volume to which the physical backups will be stored.
	ncbu/ncbu
