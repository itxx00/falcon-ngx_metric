local _VERSION = '0.1'
local result_dict = ngx.shared.result_dict
local say = ngx.say
local pairs = pairs

for _, k in pairs(result_dict:get_keys()) do
    local v = result_dict:get(k)
    say(k .. "|" .. v)

    result_dict:delete(k)
end
