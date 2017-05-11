# auto-compose

A simple shell script that watch some keys in Consul for change, 
on key update this script write the expected docker-compose yml value 
to a folder and docker-compose it up (or down if the key is absent or its value empty).

## usage

```sh
docker run \
    --net host \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/lib/auto-compose:/var/lib/auto-compose \
    pierredavidbelanger/auto-compose \
    myproject
```

This will connect to Consul on `localhost:8500` (this is why we need `--net host`), watch the `myproject` key for change. On change, it will create an `/myproject/docker-compose.yml` in `/var/lib/auto-compose` (in the container AND in the host because of the `-v`), then run `docker-compose up` (or `down` if the value is empty), and since we mounted `/var/run/docker.sock` in the container, the services containers will be created on the host's docker.

## config

Here are the `ENV` var available, and their default value:

```yml
# usualy the local Consul agent
CONSUL_URL: http://localhost:8500
# the time we wait polling for change
CONSUL_WAIT: 5m
# 0=TRACE, 1=DEBUG, 2=INFO, 3=WARN, 4=ERROR, 5=OFF
LOG_LEVEL: 2
WORK_DIR: /var/lib/auto-compose
```
