#!/bin/bash

docker run -ti \
	-e NEXTCLOUD_CONTAINER=nextcloud-app \
	-e NEXTCLOUD_DATABASE_CONTAINER=nextcloud-db \
      	-v /var/run/docker.sock:/var/run/docker.sock:ro \
	-v /home/docker/nextcloud.clews.pro:/mnt/nextcloud:ro \
	-v /home/docker/ncbu/backup:/backup \
	clewsy/ncbu

