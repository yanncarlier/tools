#!/bin/bash
docker stop $(docker ps -a -q)
# Delete all containers
docker rm -f $(docker ps -a -q)
# Delete all images
docker rmi -f $(docker images -q)
# Delete all volumes
docker system prune -a --volumes
