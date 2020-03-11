#!/bin/bash

## This script is the entry point for the ncbu container.
## It does some basic error checkings, sets up the cronjob then initiates crond in the foreground.

## Exit codes
NO_NEXTCLOUD=1

TIMESTAMP () { date +%Y-%m-%d\ %T; }

echo
echo -e "$(TIMESTAMP) - Initialising ncbu (nextcloud-backup)..."

## Check environment variables defining nextcloud app and database were provided.
## Nextcloud app container required but the backup can proceed without the database container.
echo -e "$(TIMESTAMP) - Checking environment variables provided:"
echo -e "\tNEXTCLOUD_CONTAINER=${NEXTCLOUD_CONTAINER}"
echo -e "\tNEXTCLOUD_DATABASE_CONTAINER=${NEXTCLOUD_DATABASE_CONTAINER}"
if [[ -z "${NEXTCLOUD_CONTAINER}" ]]; then
	echo -e "$(TIMESTAMP) - NEXTCLOUD_CONTAINER not provied.  Quitting"
	exit ${NO_NEXTCLOUD}
fi

## Check volumes for the nextcloud and database were provided correctly.
echo -e "$(TIMESTAMP) - Checking mounted volumes:"
if [ -n "$(ls -A /mnt/nextcloud_app)" ];	then echo -e "\tNextcloud app volume successfully mounted to /mnt/nextcloud_app"
						else echo -e "\tNextcloud app volume missing, empty or not defined."; fi

if [ -n "$(ls -A /mnt/nextcloud_db)" ];		then echo -e "\tNextcloud database volume successfully mounted to /mnt/nextcloud_db"
						else echo -e "\tNextcloud database volume missing, empty or not defined."; fi

## Check if backup directories exist.
echo -e "$(TIMESTAMP) - Checking backup volume:"
if [ ! -d /backup/nextcloud_app ];	then	echo -e "\tNo data backup exists.  This must be a new Nextcloud and/or ncbu install."
						echo -e "\tInitialising backup directories."
						mkdir /backup/nextcloud_app /backup/nextcloud_db
					else	echo -e "\tBackup exists."; fi

## Set the crontab to execute the backup script in accordance with the provided timing.
echo -e "$(TIMESTAMP) - Updating crontab with: \"${NEXTCLOUD_BACKUP_CRON} ncbu.sh\""
echo -e "${NEXTCLOUD_BACKUP_CRON} ncbu.sh" > /var/spool/cron/crontabs/root

## Run crond (i.e. all set, just waiting for the specified time to trigger the backup script.)
echo -e "$(TIMESTAMP) - Running crond in the foreground..."
crond -f
