local _VERSION = '0.1'
local mon = require("ngx_metric")
local result_dict = ngx.shared.result_dict
local servername = ngx.var.server_name
mon.query_count(result_dict, servername)
mon.latency_count(result_dict, servername)
mon.upstream_time(result_dict, servername)
