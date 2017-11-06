local _M = { version = "0.1" }

local default_time_0ms = "-"

local function str_split(instr, s)
    local inputstr = instr
    local sep = s
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    local i = 1
    local str
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end


local function cut_uri(inuri, s_len)
    local uri = inuri
    local section_len = s_len
    local uri_a = str_split(uri, "/")
    local res = ""
    local i
    for i = 1, math.min(section_len, #uri_a) do
        res = res .. "/" .. uri_a[i]
    end
    return res
end

local function req_sign(endpoint, servername, uri, tag)
    uri = uri or ""
    tag = tag or ""
    local item_sep = "|"
    --local uri_len = ngx.var.ngx_metric_uri_truncation_len
    --local uri_section_len = tonumber(uri_len)
    --if uri_section_len == nil then
    --    uri_section_len = 2
    --end
    --local sign = cut_uri(uri, uri_section_len)
        
    local tb = {endpoint, servername, uri, tag}
        --local res = t .. item_sep .. server_name .. item_sep .. cutted_uri
    local res = table.concat(tb, item_sep)
    return res
end


local function safe_incr(result_dict, inmetric, invalue)
    local res_dict = result_dict
    local metric = inmetric
    local value = invalue or 1
    local newval, err = res_dict:incr(metric, value)
    if not newval and err == "not found" then
        local ok, err = res_dict:safe_add(metric, value)
        if err == "exists" then
            res_dict:incr(metric, value)
        elseif err == "no memory" then
            ngx.log(ngx.ERR, "no memory to add: " .. metric .. ":" .. value)
        end
    end
end


local function safe_set(result_dict, inmetric, invalue)
    local res_dict = result_dict
    local metric = inmetric
    local value = invalue
    local ok, err = res_dict:safe_set(metric, value)
    if err == "no memory" then
        ngx.log(ngx.ERR, "no memory to set: " .. metric .. ":" .. value)
    end
end


function _M.latency_count(result_dict, servername)
    local res_dict = result_dict
    local reqtime = ngx.var.request_time
    if not reqtime or reqtime == default_time_0ms then
        reqtime = 0
    else
        reqtime = tonumber(reqtime)
    end
    local latency_n = reqtime
    local m
    local uri = ngx.var.metric_uri or ""
    if latency_n >= 1 and latency_n < 3 then
        m = req_sign("ngx.query.count.1-3s", servername, uri)
        safe_incr(res_dict, m)
    elseif latency_n >= 3 then
        m = req_sign("ngx.query.count.3s+", servername, uri)
        safe_incr(res_dict, m)
    end
    --local latency = res_dict:get(m) or 0.0
    --local latency = ( latency + latency_n ) / 2

    --local latency_list = res_dict:get(metric) or ""
    --latency_list = latency_list..latency..","
    --safe_set(res_dict, m, latency)
    m = req_sign("ngx.query.latency.all", servername, uri)
    safe_incr(res_dict, m, latency_n)
end


function _M.query_count(result_dict, servername)
    local res_dict = result_dict
    local status = ngx.var.status
    local status_code = tonumber(status)
    local uri = ngx.var.metric_uri or ""
    local metric
    if status_code >= 500 and status_code ~= 501 then
        metric = req_sign("ngx.query.count.5xx", servername, uri)
    elseif status_code >= 400 then
        metric = req_sign("ngx.query.count.4xx", servername, uri)
    elseif status_code >= 300 then
        metric = req_sign("ngx.query.count.3xx", servername, uri)
    end
    safe_incr(res_dict, metric)

    local metric_t = req_sign("ngx.query.start_time", servername)
    local start_time = res_dict:get(metric_t)
    if not start_time then
        safe_set(res_dict, metric_t, ngx.now())
    end
    local metric_total = req_sign("ngx.query.total", servername)
    safe_incr(res_dict, metric_total)
end


function _M.upstream_time(result_dict, servername)
    local res_dict = result_dict
    local time_o = ngx.var.upstream_response_time or ""
    local time_s = string.gsub(string.gsub(time_o, " : ", ","), " ", "")
    if time_s == "" then
        return
    end
    local resp_time_arr = str_split(time_s, ",")
    local upstream_o = ngx.var.upstream_addr or ""

    local upstream_s = string.gsub(string.gsub(upstream_o, " : ", ","), " ", "")
    if upstream_s == "" then
        return
    end
    local up_arr = str_split(upstream_s, ",")
    if #up_arr ~= #resp_time_arr then
        return
    end
    local i
    local latency_all = 0.0
    local m
    for i = 1, #up_arr do
        local latency_n = resp_time_arr[i]
        if not latency_n or latency_n == default_time_0ms then
	        latency_n = 0
        else
	        latency_n = tonumber(latency_n)
        end
        local ip = up_arr[i]
        --local m_all = req_sign("ngx.upstream.contacts", servername, ip)
        --safe_incr(res_dict, m_all)
        if latency_n >= 1 and latency_n < 3 then
            m = req_sign("ngx.upstream.count.1-3s", servername)
            safe_incr(res_dict, m)
        elseif latency_n >= 3 then
            m = req_sign("ngx.upstream.count.3s+", servername)
            safe_incr(res_dict, m)
        end
        if latency_n >= 6 then
            --local uri = ngx.var.uri or ""
            --local sign = cut_uri(uri, 2)
            local uri = ngx.var.metric_uri or ""
            m = req_sign("ngx.upstream.count.6s+", servername, ip, uri)
            safe_incr(res_dict, m)
        end
        --local latency = res_dict:get(m) or 0.0
        --local latency = ( latency + latency_n ) / 2
        --safe_set(res_dict, m, latency)
        i = i + 1
        latency_all = latency_all + latency_n
    end
    m = req_sign("ngx.upstream.latency.all", servername)
    safe_incr(res_dict, m, latency_all)
    local mc = req_sign("ngx.upstream.contact", servername)
    safe_incr(res_dict, mc)
end


return _M
