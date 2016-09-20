# falcon-ngx_metric

从 https://github.com/GuyCheung/falcon-ngx_metric fork过来的，修改的比较多


## 监控指标说明

```
 	ngx.query.qps				请求QPS
  ngx.query.avg_latency  		请求平均延迟
 	ngx.query.count.1-3s		1-3s请求数量
	ngx.query.count.3s+			3s以上请求数量
	ngx.query.count.4xx			4xx错误数量
	ngx.query.count.5xx			5xx错误数量
	ngx.upstream.avg_latency	后端平均延迟
	ngx.upstream.count.1-3s		后端1-3s请求数量
	ngx.upstream.count.3s+		3s以上请求数量
	ngx.upstream.count.6s+		6s以上请求数量
```


## 监控部署

###1 部署nginx监控lua脚本

```
/usr/local/nginx/conf/lua/ngx_metric.lua
/usr/local/nginx/conf/lua/ngx_metric_hook.lua
/usr/local/nginx/conf/lua/ngx_metric_stats.lua
```

###2 新增nginx配置文件

/usr/local/nginx/conf/common/ngx_metric.conf

修改nginx.conf加载配置：

```
include nginx_metric.conf
```

###3 nginx机器安装falcon-agent

需配合falcon agent使用

###4 数据采集脚本

采集上报脚本/usr/local/nginx/bin/collect.py，配置crontab每分钟采集一次：

```
* * * * *       /usr/local/nginx/bin/collect.py >/dev/null 2>&1 &
```
