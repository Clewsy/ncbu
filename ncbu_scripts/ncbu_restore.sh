#!/bin/bash

## This script must be called manually from witin the ncbu container or externally (e.g. "docker exec <ncbu-container-name> ncbu_restore.sh")
## The script will attempt to restore a nextcloud instance (app and database) from a backup that was previously created by the ncbu.sh script.
## If restoration is required for migration to a new host, ensure a new nextcloud instance is initialised with the same admin user and database
## configurations that were in place during the last backup. 

## Exit codes:
NO_MAINT=1	## Aborted due to failure to enter maintenance mode.
SUCCESS=0	## Everything seems to have worked as expected.

## Text formatting for stdout.
BOLD="\033[01;37m"
RESET="\033[0m"

## Function to print current date and time (in bold).
TIMESTAMP () {  echo -ne "${BOLD}$(date +%Y-%m-%d\ %T)${RESET}" ; }

echo -e "\n$(TIMESTAMP) - Running ncbu restore..."

## Attempt to put nextcloud into maintenance mode so that all files and the database are locked.
## If setting mainenance mode to on fails, print an error then exit. 
echo -e "$(TIMESTAMP) - Putting ${NEXTCLOUD_CONTAINER} into maintenance mode..."
if ! docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --on; then
	echo -e "Error - unable to enter maintenance mode.  Has the nextcloud app and database been initialised and connected?"
	echo -e "Aborting restoration."
	exit ${NO_MAINT}
else
	## Sync the ncbu nextcloud data backup to the nextcloud app volume.
	if [[ -n "$(ls -A /backup/nextcloud_app)" ]]; then	## First ensure there is data in the backup.
		echo -e "$(TIMESTAMP) - Nextcloud data restore from ncbu: Syncing /backup/nextcloud_app to ${NEXTCLOUD_CONTAINER} volume..."
		rsync --acls --times --perms --archive --verbose --one-file-system --delete --human-readable --progress /backup/nextcloud_app/* /mnt/nextcloud_app/.
		echo -e "$(TIMESTAMP) - Finished nextcloud data sync from backup."
	fi

	## If a database container was defined, sync the ncbu nextcloud database backup to the nextcloud database volume.
	if [[ -n "${NEXTCLOUD_DATABASE_CONTAINER}" ]]; then
		if [[ -n "$(ls -A /backup/nextcloud_db)" ]]; then	## First ensure there is data in the backup.
			echo -e "$(TIMESTAMP) - Nextcloud database restore from ncbu physical copy: Syncing /backup/nextcloud_db to ${NEXTCLOUD_DATABASE_CONTAINER} volume..."
			rsync --acls --times --perms --archive --verbose --one-file-system --delete --human-readable --progress /backup/nextcloud_db/* /mnt/nextcloud_db/.
			echo -e "$(TIMESTAMP) - Finished nextcloud database sync from backup."
		fi
	fi

	## Take nextcloud out of maintenance mode so that normal usage can resume.
	echo -e "$(TIMESTAMP) - Taking ${NEXTCLOUD_CONTAINER} out of maintenance mode..."
	docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --off

	## Scan the data files and update the cache accordingly.  This may take a while.
	echo -e "$(TIMESTAMP) - Scanning the ${NEXTCLOUD_CONTAINER} data files and updating the cache accordingly."
	echo -e "\t(This may take a while but the nextcloud instance should be accessible while the scan runs.)"
	docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ files:scan --all -v
	echo -e "$(TIMESTAMP) - All done.\n"
	exit ${SUCCESS}
fi
