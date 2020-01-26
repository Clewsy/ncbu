#!/bin/bash

## This script is run periodically to determine if the container is "healthy".
## To return HEALTHY (0), crond must be running and the defined $NEXTCLOUD_CONTAINER must be accessible and running.

## Exit codes
HEALTHY=0
UNHEALTHY=1

# Ensure crond is running:
if ! pgrep crond; then exit $UNHEALTHY; fi

# Ensure the defined nextcloud app container is still present and running:
if [ $(docker inspect --format '{{.State.Running}}' $NEXTCLOUD_CONTAINER) != "true" ]; then exit $UNHEALTHY; fi

# Everything seems okay.
exit $HEALTHY