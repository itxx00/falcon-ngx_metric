#!/bin/env python
# -*- encoding: utf-8 -*-

import sys, urllib2, time, json, traceback
from optparse import OptionParser
import subprocess

NG_STATUS_URI = 'http://127.0.0.1:9091/monitor/basic_status'
api = 'http://127.0.0.1:1988/v1/push'
batch = 500


def execute(cmd):
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
    return p.communicate()

def push(t):
    #print json.dumps(t, indent=4, sort_keys=True)
    #print len(t)
    try:
        urllib2.urlopen(
            url = api,
            data = json.dumps(t)
        )
    except:
        pass

def collect():
    global options
    datapoints = []
    step = options.falcon_step
    try:
        content = urllib2.urlopen(NG_STATUS_URI).read()
        ts = int(time.time())
        start_time = {}
        query_latency = {}
        upstream_latency = {}
        query_total = {}
        upstream_contact = {}
        no_qps = {}
        cmd = "/sbin/ifconfig eth1 2>/dev/null |grep 'inet addr:'|awk -F ':' '{ print $2 }'|awk '{ print $1 }'"
        stdout, stderr = execute(cmd)
        if stdout == "":
            cmd = "/sbin/ip route|egrep 'src 172\.|src 10\.'|awk '{print $NF}'|head -n 1"
            stdout, stderr = execute(cmd)
        endpoint = stdout.splitlines()[0]

        for line in content.splitlines():
            datapoint = {}
            value = False
            metric, servername, tag1, tag2, v = line.split(options.ngx_out_sep)
            if options.use_ngx_host:
                endpoint = servername
            if metric == 'ngx.query.start_time':
                start_time[servername] = int(float(v))
                continue
            if metric == 'ngx.query.latency.all':
                query_latency[servername] = float(v)
                if servername in query_total:
                    tags = 'domain=%s' % servername
                    metric = "ngx.query.avg_latency"
                    value = query_latency[servername] / query_total[servername]
                    del query_total[servername]
                else:
                    continue
            if metric == 'ngx.upstream.latency.all':
                upstream_latency[servername] = float(v)
                if servername in upstream_contact:
                    tags = 'domain=%s' % servername
                    metric = "ngx.upstream.avg_latency"
                    value = upstream_latency[servername] / upstream_contact[servername]
                    del upstream_contact[servername]
                else:
                    continue
            if servername == 'nginx_metric' or servername == '_':
                continue
            if 'ngx.query.count' in metric:
                value = v
                tags = 'domain=%s' % servername
                if tag2 != "":
                    tags = 'domain=%s,uri=%s' % (servername, tag2)
            elif 'ngx.upstream.count' in metric:
                value = v
                tags = 'domain=%s' % (servername)
                if tag1 != "":
                    tags = 'domain=%s,upstream=%s' % (servername, tag1)
                if tag2 != "":
                    tags = 'domain=%s,uri=%s' % (servername, tag2)
                if tag1 != "" and tag2 != "":
                    tags = 'domain=%s,upstream=%s,uri=%s' % (servername, tag1, tag2)
            elif metric == 'ngx.query.total':
                tags = 'domain=%s' % servername
                if servername in start_time:
                    total_time = ts - start_time[servername]
                    if total_time > 0:
                        metric = "ngx.query.qps"
                        value = int(v) / total_time
                    else:
                        no_qps[servername] = int(v)
                if servername in query_latency:# and servername not in query_total:
                    metric = "ngx.query.avg_latency"
                    value = query_latency[servername] / int(v)
                else:
                    query_total[servername] = int(float(v))
            elif metric == "ngx.upstream.contact":
                tags = 'domain=%s' % servername
                if servername in upstream_latency:# and servername not in upstream_contact:
                    metric = "ngx.upstream.avg_latency"
                    value = upstream_latency[servername] / int(v)
                else:
                    upstream_contact[servername] = int(float(v))
            #else:
            #    tags = 'domain=%s,tag1=%s,tag2=%s' % (servername, tag1, tag2)
            if value:
                datapoint = {
                    "metric": metric,
                    "endpoint": endpoint,
                    "timestamp": ts,
                    "step": step,
                    "counterType": "GAUGE",
                    "value": value,
                    'tags': tags
                }
                datapoints.append(datapoint)
            if len(datapoints) >= batch:
                push(datapoints)
                datapoints = []
        push(datapoints)

    except Exception as e:
        traceback.print_exc(file = sys.stderr)

    sys.stdout.flush()
    sys.stderr.flush()

if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option('--use-ngx-host', action='store_true', dest='use_ngx_host', default=False, help='use the ngx collect lib output host as service column, default read self')
    parser.add_option('--service', dest='service', default='ngx_metric', help='logic service name(endpoint in falcon) of metrics, use nginx service_name as the value when --use-ngx-host specified. default is ngx_metric')

    parser.add_option('--falcon-step', dest='falcon_step', type='int', default=60, help='Falcon only. metric step')

    parser.add_option('--ngx-out-sep', dest='ngx_out_sep', default='|', help='ngx output status seperator, default is "|"')

    (options, args) = parser.parse_args()

    sys.exit(collect())
