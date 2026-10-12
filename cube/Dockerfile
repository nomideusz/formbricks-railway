# Upstream's Cube image ships without config; their compose bind-mounts cube.js and
# the schema from the formbricks repo (docker/cube at the 6.0.2 tag). Railway has no
# bind mounts, so they are baked in here.
FROM ghcr.io/formbricks/cube:1.7.47-1
COPY cube.js /cube/conf/cube.js
COPY model /cube/conf/model
