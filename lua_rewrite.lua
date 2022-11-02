-- set $serverId 1;
-- set $server_id_file /www/pmi.dvue.ru/release/current-line-2;
-- rewrite_by_lua_file /www/pmi.dvue.ru/release/lua/lua_rewrite.lua;
-- root /www/pmi.dvue.ru/release/line_$serverId/web;

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

if nil == ngx.var.server_id_file then
    ngx.log(ngx.ERR, "'server_id_file' must be set")
    return ngx.exit(500)
end

local activeServerId;
if file_exists(ngx.var.server_id_file) then
    activeServerId = '2';
else
    activeServerId = '1'
end

local redis = require "resty.redis"
local red

function redis_connect()
    if nil == red then
        red = redis:new()
        local ok, err = red:connect("127.0.0.1", 6379)
        if not ok then
            ngx.log(ngx.ERR, "Unable to connect Redis: ", err)
            return ngx.exit(500)
        end
    end
end

function redis_get(name)
    redis_connect()
    local res, err = red:get(name)
    if res == ngx.null then
        return nil
    else
        return res
    end
end

function redis_set(name, value)
    local ok, err = red:set(name, value)
end

-- -------------------

local markerName = 'server_id'
local cookieName = 'cookie_' .. markerName
local cookieValue = nil
local bearer = ngx.req.get_headers()["authorization"]

if nil == bearer then
    local setCookie = false
    if (ngx.var[cookieName] == nil) then
        cookieValue = activeServerId
        setCookie = true
    else
        cookieValue = ngx.var[cookieName]
    end

    if (cookieValue ~= '1') and (cookieValue ~= '2') then
      cookieValue = activeServerId
      setCookie = true
    end

    if setCookie then
        ngx.header["Set-Cookie"] = markerName .. '=' .. cookieValue .. "; Path=/;"
    end

else
    local setCookie = false
    local redisKey = 'server-id-' .. bearer
    cookieValue = redis_get(redisKey)
    if nil == cookieValue then
        cookieValue = activeServerId
    end

    if (cookieValue ~= '1') and (cookieValue ~= '2') then
      cookieValue = activeServerId
      setCookie = true
    end

    if setCookie then
        redis_set(redisKey, activeServerId)
    end
end

ngx.ctx.serverId = cookieValue
ngx.var.serverId = cookieValue
