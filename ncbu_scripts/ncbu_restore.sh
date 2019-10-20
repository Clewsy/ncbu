#! /bin/bash

TIMESTAMP () { date +%D-%T; }

echo
echo -e "$(TIMESTAMP) - Running ncbu restore..."

## Put nextcloud into maintenance mode so that all files and the database are locked.
echo -e "$(TIMESTAMP) - Putting ${NEXTCLOUD_CONTAINER} into maintenance mode..."
docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --on

## Sync the ncbu nextcloud data backup to the nextcloud app volume.
if [[ ! -z "$(ls -A /backup/nextcloud_app)" ]]; then	## First ensure there is data in the backup.
	echo -e "$(TIMESTAMP) - Nextcloud data restore from ncbu: Syncing /backup/nextcloud_app to ${NEXTCLOUD_CONTAINER} volume..."
	rsync --acls --archive --verbose --one-file-system --delete --human-readable --progress /backup/nextcloud_app/* /mnt/nextcloud_app/.
	echo -e "$(TIMESTAMP) - Finished nextcloud data sync from backup."
fi

## If a database container was defined, sync the ncbu nextcloud database backup to the nextcloud database volume.
if [[ -n "${NEXTCLOUD_DATABASE_CONTAINER}" ]]; then
	if [[ ! -z "$(ls -A /backup/nextcloud_db)" ]]; then	## First ensure there is data in the backup.
	        echo -e "$(TIMESTAMP) - Nextcloud database restore from ncbu physical copy: Syncing /backup/nextcloud_db to ${NEXTCLOUD_DATABASE_CONTAINER} volume..."
	        rsync --acls --archive --verbose --one-file-system --delete --human-readable --progress /backup/nextcloud_db/* /mnt/nextcloud_db/.
	        echo -e "$(TIMESTAMP) - Finished nextcloud database sync from backup."
	fi
fi

## Take nextcloud out of maintenance mode so that normal usage can resume.
echo -e "$(TIMESTAMP) - Taking ${NEXTCLOUD_CONTAINER} out of maintenance mode..."
docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --off

## Scan the data files and update the cache accordingly.  This may take a while.
echo -e "$(TIMESTAMP) - Scanning the ${NEXTCLOUD_CONTAINER} data files and updating the cache accordingly."
echo -e "(This may take a while but the nextcloud instance should be accessible while the scan runs.)"
docker exec -u ${NEXTCLOUD_EXEC_USER} ${NEXTCLOUD_CONTAINER} php occ files:scan --all -v

echo -e "$(TIMESTAMP) - All done."
echo