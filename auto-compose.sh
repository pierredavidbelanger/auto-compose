#!/bin/sh

consulUrl=${CONSUL_URL:-http://localhost:8500}
consulWait=${CONSUL_WAIT:-300}
logLevel=${LOG_LEVEL:-2}
workDir=${WORK_DIR:-/var/lib/auto-compose}

[ $logLevel -le 0 ] && set -x

log() {
    level='TRACE'
    case $1 in
        1) level='DEBUG';;
        2) level='INFO';;
        3) level='WARN';;
        4) level='ERROR';;
        5) return 0;;
    esac
    echo "$(date +%FT%T%z) [$level] $2"
}

log_debug() {
    [ $logLevel -le 1 ] && log 1 "$1"
}

log_info() {
    [ $logLevel -le 2 ] && log 2 "$1"
}

log_warn() {
    [ $logLevel -le 3 ] && log 3 "$1"
}

log_error() {
    [ $logLevel -le 4 ] && log 4 "$1"
}

auto_compose_update() {
    keyDir=$1
    yml=$2
    cd $keyDir
    if [ "$yml" == "" ]; then
        if [ -f docker-compose.yml ]; then
            log_info "($keyDir) docker-compose down --remove-orphans"
            docker-compose down --remove-orphans
            rm -f docker-compose.yml
        fi
        return 0
    fi
    echo "$yml" > docker-compose.yml
    log_info "($keyDir) docker-compose pull"
    docker-compose pull
    log_info "($keyDir) docker-compose up -d --no-color --remove-orphans"
    docker-compose up -d --no-color --remove-orphans
}

auto_compose_watch() {
    key="$1"
    keyDir="$workDir/$1"
    mkdir -p $keyDir || (log_error "Cannot mkdir $keyDir" && return 1)
    trap "log_debug 'trap SIGTERM on worker thread'; trap - SIGTERM; auto_compose_update $keyDir ''; kill 0; exit 143" SIGTERM
    stepbackTime=1
    lastIndex=0
    while true; do
        [ $stepbackTime -ge $consulWait ] && stepbackTime=$consulWait
        url="$consulUrl/v1/kv/$1?index=$lastIndex&wait=${consulWait}s"
        log_debug "($keyDir) Poll $url"
        json=$(curl -sS $url)
        if [ $? -ne 0 ]; then
            log_warn "($keyDir) Poll error, sleep $stepbackTime seconds"
            sleep $stepbackTime
            stepbackTime=$(($stepbackTime + 1))
            continue
        fi
        if [ "$json" == "" ]; then
            log_debug "($keyDir) Poll empty response, sleep $stepbackTime seconds"
            sleep $stepbackTime
            stepbackTime=$(($stepbackTime + 1))
            continue
        fi
        stepbackTime=1
        thisIndex=$(echo $json | jq -r '.[].ModifyIndex // empty')
        if [ $thisIndex -eq $lastIndex ]; then
            log_debug "($keyDir) Poll nothing new"
            continue
        fi
        lastIndex=$thisIndex
        log_debug "($keyDir) Poll something new!"
        yml=$(echo $json | jq -r '.[].Value // empty' | base64 -d)
        auto_compose_update "$keyDir" "$yml"
    done
}

main() {
    trap "log_debug 'trap SIGINT or SIGTERM on main thread'; trap - SIGTERM; kill 0; wait; exit 143" SIGINT SIGTERM
    log_info 'Auto Compose'
    for key in "$@"
    do
        auto_compose_watch "$key" &
    done
    while true; do
        sleep 60
    done
}

main "$@"
