# Upstream's Cube image ships without config; their compose bind-mounts cube.js and
# the schema from the formbricks repo (docker/cube at the 6.1.3 tag). Railway has no
# bind mounts, so they are baked in here.
FROM ghcr.io/formbricks/cube:1.8.8-3
COPY cube.js /cube/conf/cube.js
COPY model /cube/conf/model
