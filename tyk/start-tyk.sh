#!/bin/bash
USAGE="--> Usage: ./start.sh PORT SECRET ORGID APIKEY (REDIS HOST) (REDIS PORT) (REDIS PW)"

if [ -z "$1" ]
then
        echo "Please specify a listen port for Tyk"
        echo $USAGE
        exit
fi

if [ -z "$2" ]
then
        echo "Please specify a Tyk Secret (REST API)"
        echo $USAGE
        exit
fi

if [ -z "$3" ]
then
        echo "Please specify an Organisation ID"
        echo $USAGE
        exit
fi

if [ -z "$4" ]
then
        echo "Please specify an API Key"
        echo $USAGE
        exit
fi

REDISHOST=$5
if [ -z "$5" ]
then
        echo "Using Redis localhost"
        REDISHOST=localhost
fi

RPORT=$6
if [ -z "$6" ]
then
        echo "Using Redis default port"
        RPORT=6379
fi

REDISPW=$7
if [ -z "$7" ]
then
        echo "Using Redis without password"
        REDISPW=""
fi 

cwd=$(pwd)
if [ ! -d "confs" ]; then
  mkdir confs
fi

PORT=$1
SECRET=$2
ORGID=$3
APIKEY=$4

docker stop tyk_hybrid && docker rm tyk_hybrid
docker pull tykio/tyk-hybrid-docker:latest

CONTAINER=tykio/tyk-hybrid-docker
docker run --restart always -v $cwd/confs:/etc/nginx/sites-enabled \
        -d --name tyk_hybrid \
        -v $cwd/templates/default_webhook.json:/opt/tyk/templates/default_webhook.json \
        -v $cwd/logs:/opt/tyk/logs \
        -p $PORT:$PORT \
        -p 80:80 \
        -e PORT=$PORT \
        -e SECRET=$SECRET \
        -e ORGID=$ORGID \
        -e APIKEY=$APIKEY \
        -e REDISHOST=$REDISHOST \
        -e REDISPW=$REDISPW \
        -e RPORT=$RPORT \
        -e BINDSLUG=1 \
        -e TYKVERSION='-python' \
        -e TYK_GW_UPTIMETESTS_CONFIG_TIMEWAIT=3 \
        -e TYK_GW_UPTIMETESTS_CONFIG_FAILURETRIGGERSAMPLESIZE=3 \
        -e TYK_GW_SECRET=$SECRET \
        -e TYK_GW_LISTENPORT=$PORT \
        -e TYK_GW_APPPATH="./test_apps/" \
        -e TYK_GW_ANALYTICSCONFIG_GEOIPDBLOCATION="/opt/tyk/GeoLite2-City.mmdb" \
        -e TYK_GW_SLAVEOPTIONS_APIKEY=$APIKEY \
        -e TYK_GW_SLAVEOPTIONS_RPCKEY=$ORGID \
        -e TYK_GW_SLAVEOPTIONS_BINDTOSLUGSINSTEADOFLISTENPATHS="true" \
        -e TYK_GW_ENABLENONTRANSACTIONALRATELIMITER="false" \
        -e TYK_GW_ENABLESENTINELRATELIMITER="false" \
        -e TYK_GW_ENABLEREDISROLLINGLIMITER="true" \
        -e TYK_GW_COPROCESSOPTIONS_ENABLECOPROCESS="true" \
        -e TYK_GW_USELOGSTASH="true" \
        -e TYK_GW_LOGSTASHTRANSPORT="tcp" \
        -e TYK_GW_LOGSTASHNETWORKADDR="192.168.2.17:5045" \
        -e TYK_GW_STORAGE_HOSTS="$REDISHOST:$RPORT"
        $CONTAINER

# Add the following environment variable to disable the nginx service
# -e DISABLENGINX=1 \

# Add the following environment variable to have the node bind URLs to API IDs instead of Slugs
# -e BINDSLUG=0 \
        
echo "Tyk Hybrid Node Running"
echo "- To test the node, use port $PORT"
