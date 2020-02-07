#! /bin/bash

## This is the backup script that is called as a cron job.
## It will put nextcloud into maintenance mode then create physical snapshot backups of the nextcloud app and nextcloud database volumes. 

## Exit codes:
NO_MAINT=1	## Aborted due to failure to enter maintenance mode.
SUCCESS=0	## Everything seems to have worked as expected.

TIMESTAMP () { date +%Y-%m-%d\ %T; }

echo
echo -e "$(TIMESTAMP) - Running ncbu (nextcloud backup)..."

## Attempt to put nextcloud into maintenance mode so that all files and the database are locked.
## If setting mainenance mode to on fails, print an error then exit. 
echo -e "$(TIMESTAMP) - Putting ${NEXTCLOUD_CONTAINER} into maintenance mode..."
if ! docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --on; then
	echo -e "Error - unable to enter maintenance mode.  Has the nextcloud app and database been initialised and connected?"
	echo -e "Aborting backup."
	exit ${NO_MAINT}
else
	## Sync the nextcloud app volume to the nextcloud-bu volume.
	echo -e "$(TIMESTAMP) - Nextcloud data backup: Syncing ${NEXTCLOUD_CONTAINER} volume to /backup..."
	rsync --acls --times --perms --archive --verbose --one-file-system --delete --human-readable --progress /mnt/nextcloud_app/* /backup/nextcloud_app/.
	echo -e "$(TIMESTAMP) - Finished nextcloud data sync."
       
	## Make sure the permissions are set for group read access (www-data by default) at the top level of the data directory.
	## By default, the official nextcloud container stes the GID of the data directory to root.
	## The chown command below has no effect on the nextcloud app, but allows copying of the physical backup without being root or in the root group.
	echo -e "${TIMESTAMP} - Setting permission of nextcloud data directory to :${NEXTCLOUD_EXEC_USER_GID}"
        chown -R :${NEXTCLOUD_EXEC_USER_GID} /backup/nextcloud_app/data
	echo -e "$(TIMESTAMP) - Ensure user on host machine is part of group id GID=${NEXTCLOUD_EXEC_USER_GID} for read access to backup."

	## If a database container was defined, sync the database volume to the nextcloud-bu volume.
	if [[ -n "${NEXTCLOUD_DATABASE_CONTAINER}" ]]; then
		echo -e "$(TIMESTAMP) - Nextcloud database backup (physical copy): Syncing ${NEXTCLOUD_DATABASE_CONTAINER} volume to /backup..."
		rsync --acls --times --perms --archive --verbose --one-file-system --delete --human-readable --progress /mnt/nextcloud_db/* /backup/nextcloud_db/.
		echo -e "$(TIMESTAMP) - Finished nextcloud database sync."
	fi

	## Take nextcloud out of maintenance mode so that normal usage can resume.
	echo -e "$(TIMESTAMP) - Taking ${NEXTCLOUD_CONTAINER} out of maintenance mode..."
	docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --off
	echo -e "$(TIMESTAMP) - All done."
	echo
	exit ${SUCCESS}
fi
