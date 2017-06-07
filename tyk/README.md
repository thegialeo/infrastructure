# ORS API gateway

## Top-level load balancer

The nginx running on `ors-gateway` performs as the major and only entrance of
all OpenRouteService API traffic from both the ORS developers and the
[openrouteservice.org](https://openrouteservice.org) public web client.

### API endpoints and rate limits

It manages all the API endpoints including:

-   `/directions`
-   `/geocoding`
-   `/isochrones`
-   `/places`
-   `/pdirections`
-   `/pgeocoding`
-   `/pisochrones`
-   `/pplaces`

For each API endpoint dedicated for ORS public client (only with the `p`
prefix), an IP-based rate limit rule is defined. All other policy or key-level
rate limits are defined in tyk gateway.

### Tyk gateway load-balancing

The incomming http requests will be balanced proxies to two tyk gateways
running in docker containers on `ors-gateway` and `ors-gateway-worker`.

### API level load-balancing

For each API, two backend servers, i.e. `ors-sesame` and `ors-rice` are added in 
the load-balancing pool. Incoming requests will be sent to these two backends
in round-robin mode.

Tyk gateway will check their health status by
accessing the `http://{ors-backend-internal-IP-address}:8080/ors/health`
regularly, which is called [uptime tests](https://tyk.io/tyk-documentation/ensure-high-availability/uptime-tests/) 
in tyk. If any response instead of http status `200 OK` is received, a `HOST
DOWN` event will be triggered, then the event handling process will be launched
as described in the "Event handlers" section below.

### Configuration and logging analytics

The config file is located at
`/etc/nginx/site-available/api.openrouteservice.org` . When modified this file,
use `sudo service nginx reload` or `sudo service nginx restart` with root privilege to
enable it. The access and error log of nginx is located in `/var/log/nginx/`
directory. **Note** that the access log should NOT be disabled because it is
the data source of piwik log analyzer on `ors-sentinel`.

All the access log record will be sent to the piwik service on `ors-sentinel`
as mentioned above via this pipeline:

`nginx access.log -> rsyslog -> piwik`

It should be noted that sometimes this will get stuck. It's usually the problem
of rsyslog. So just restart the rsyslog service on `ors-gateway` with the following 
command will let it back on duty.

`sudo service rsyslog restart`

## Tyk gateway

We use [tyk hybrid
gateway](https://tyk.io/tyk-documentation/get-started/with-tyk-hybrid/) with
two load-balanced nodes in ORS API system, which means the API gateways are
running in our private cloud servers while the tyk gateway dashboard as well as
the developers portal are hosted in tyk's public cloud. 

### Fresh start a new container

Tyk hybrid gateway is maintained with docker. To install it, one needs to refer 
to the official document [here](https://tyk.io/tyk-documentation/get-started/with-tyk-hybrid/tutorials/install-hybrid-gateway/). 
Specifically, the command line arguments `RPC-CREDENTIALS` and
`API-CREDENTIALS` for the `start.sh` script can be found in the tyk dashboard.
Only the `TYK-SECRET` is generated by yourself. And all these argument values
should be identical on both gateway nodes. By running this shell script, the
current tyk gateway container will be stopped and removed. The corresponding 
image will be deleted first. Then, it will fetch the latest version of the
image from dockerhub and launch it.

**Note** that we are not using the official `start.sh` because there are
a couple of bugs confirmed by tyk technical support in it. So we use a modified
version named `start-bundle-python.sh` which will start a tyk gateway container
with python support (for running the plugins), as well as mount the correct
local files in `templates/` and `tyk_conf/` to the container. 

As an example, I paste the current command of starting a fresh new tyk gateway
container here (root privilege is needed, working dir is ~/tyk/):

    sudo ./start-bundle-python.sh 8080 36010471e7c6aa3e0d91104ceb09119f 58d904a497c67e00015b45fc fb537f41eef94b4c615a1b6414ae0920

### Restart the container

Sometimes, when some changes are made in the tyk dashboard, it does not take
effect. As the official document says, the tyk gateways running in our private cloud
communicate with the dashboard every 30 seconds. In practice, however, we found
that this syncing strategy has problems from time to time. When this occurs,
the simplest way to solve it is to restart the container **ONE BY ONE (to
ensure there is at least one tyk gateway node alive)** on both nodes with the 
following command (no privilege needed).

    docker container restart tyk_hybrid

### Check the logs

Use the following command to check tyk gateway logs (no privilege needed).

    docker logs --tail=200 --follow tyk_hybrid

If you see something at the end of the logs like:

    time="Jun  7 10:03:59" level=info msg="Gateway started (v2.3.5)"
    time="Jun  7 10:03:59" level=info msg="--> Listening on address: (open interface)"
    time="Jun  7 10:03:59" level=info msg="--> Listening on port: 8080"
    time="Jun  7 10:03:59" level=info msg="--> PID: 42"

that means it is working properly.

### Python plugins

The fine-grained, querystring parameters level access controls for each ORS API
are implemented with tyk rich plugins in Python. In a nutshell, the plugin
should be written according to
a [template](https://github.com/TykTechnologies/tyk-plugin-demo-python),
compiled into a bundle `.zip` file with `tyk-cli`, then uploaded to
`https://api.openrouteservice.org/api-plugins/`. After that, one can attach
a plugin to an API by specifying the bundle file name (`xxxx.zip`). The bundle
zip file will be downloaded, uncompressed, compiled with `cythonize` and cached
in the local `bundles/` directory by the tyk gateway as the container starts. 

### Event handling

It's allowed to define custom event handlers in tyk to deal with some special
situations, e.g. backend server down/up, quota exceeds, etc. with [web
hooks](https://tyk.io/tyk-documentation/report-monitor-trigger-events/webhooks/). 
With web hooks defined and associated with an specific API, an http request
will be sent to the target "listener" when some events occur. In ORS API
system, the event listener is located on `ors-sentinel`, at the address of
`http://192.168.2.19/gateway-events`. Note that here we have to use the
internal IP address of `ors-sentinel` because there is a problem when accessing
it with its public domain name within the private cloud. 

At the event listener address above,
an [ors_api_alerts service](https://gitlab.gistools.geog.uni-heidelberg.de/giscience/openrouteservice/infrastructure/tree/master/tyk/event_handlers) written in Python and Flask is
running with uwsgi. Its job is to send e-mails to ORS administrators (defined
in the `contacts.json` file) when it receives POST request from tyk gateway. To
check the log of ors_api_alerts, use this command:

    tail -f /var/log/ors/api_alerts.log

To start this service on `ors-sentinel` in case it has any problems (no
root privilege needed):

    uwsgi --ini ~/projects/infrastructure/tyk/event_handlers/ors_api_alerts-uwsgi.ini

To stop the service:

    uwsgi --stop /tmp/orsalerts.pid

If there is problem to stop the service, just kill the uwsgi root process
(whose parent process id is 1, the other two are worker processes), and start 
it again with the above command.