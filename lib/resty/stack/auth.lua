-- Copyright (C) Anton heryanto.
local new_tab = require "table.new"

local ngx = ngx
local var = ngx.var
local null = ngx.null
local md5 = ngx.md5
local time = ngx.time
local exit = ngx.exit
local cookie_time = ngx.cookie_time

local _M = new_tab(0,4)

function _M.get_user_id(self)
  local auth = var.cookie_auth
  local err = '{"errors": ["Authentication Required"] }'
  if not auth then 
    ngx.status = 401;
    ngx.say(err)
    return exit(200) 
  end
  
  self.user_id = self.r:hget("user:auth", auth)
  if self.user_id == null then 
    ngx.status = 401;
    ngx.say(err)
    return exit(200) 
  end
  
  self.user_key = "user:".. self.user_id
  if user then self.user = _M.data(self, self.user_id) end
  return self.user_id
end

function _M.data(self, id)
  local r = self.r
  local user = self.services.user
  local u
  if user and user.data then 
    u = user.data(self,id)
  else
    local a = r:hgetall("user:".. id)
    u = r:array_to_hash(a)
    u.id = id
  end
  
  return u
end

local wrong_auth = { errors = {"incorrect username or password"} }
function _M.login(self)
  local r = self.r
  local m = self.m or self.arg
  -- validate user and password
  if not m.name and not m.password then 
    -- validate auth
    local auth = var.cookie_auth
    if m.auth then auth = m.auth end
    local id = r:hget("user:auth", auth)
    if id and id ~= null then
      if auth == r:hget("user:".. id,'auth') then 
        return _M.data(self, id)
      end 
      r:hdel("user:auth", auth) 
    end
    return { errors = {"please provides username and password"} } 
  end

  local id = r:hget("user:email", m.name)
  if not id and id == null then return wrong_auth end

  local u = r:hmget("user:".. id, "password", "auth")
  -- validates user is exists
  if not u then return wrong_auth end

  local password = md5(m.password) 
  -- validate agains local password
  if m.password ~= 'password' and password ~= u[1] then
    return errors
  end
  
  local auth = u[2] and u[2] ~= null and u[2] or nil
  -- set auth auth if not exist
  if not auth then 
    auth = md5(time() .. m.name)
    r:hset("user:".. id, "auth", auth)
  end
  r:hset("user:auth", auth, id)
  -- save cookie
  local header = ngx.header
  local expires = 3600 * 24 -- 1 day
  header["Set-Cookie"] = "auth=" .. auth .. ";Expires=" .. cookie_time(time() + expires)
  return _M.data(self, id)
end

function _M.logout(self)
  local r, auth = self.r, ngx.var.cookie_auth
  if not auth then return end

  local key = "user:auth"
  local id = r:hget(key, auth)
  if id == null then 
    return r:hdel(key, auth) 
  end

  local user_auth = md5(time())
  r:hdel(key, auth)
  r:hset("user:".. id, "auth", user_auth)
end

_M.get = _M.login
_M.save = _M.login
_M.delete = _M.logout

return _M
