--[[
Copyright (c) 2016-2018 uscq <yuleader@163.com> All rights reserved.

Licensed under the MIT License (the "License"); you may not use this file except
in compliance with the License. You may obtain a copy of the License at
  http://opensource.org/licenses/MIT
Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations.
--]]

local setclass = setmetatable
local getclass = getmetatable
local pairs = pairs

local function indexing (self, key)
    if key == nil then return end

    local class = getclass(self)
    local t = class
    repeat
        local val = t[key]
        if val ~= nil then
            -- it would fire __newindex/__eq when appropriate
            if t ~= class then class[key] = val end
            self[key] = val
            return val
        end
        t = t.__super
    until not t
end

typeof = getclass

function class (super)
    local drived = {
        __index = indexing,
        __super = super,
    }
    
    if super then
        drived.__tostring = super.__tostring
        drived.__gc = super.__gc
        setclass(drived, { __index = super })
    end
    
    return drived
end

function new (class, ...)
    local obj = setclass({ }, class)
    local __ctor = class.__ctor
    if __ctor then __ctor(obj, ...) end
    return obj
end

function delete (obj)
    local gc = obj.__gc
    if gc then gc(obj) end
    setclass(obj, nil)
    for k in pairs(obj) do obj[k] = nil end
end

function is_a (obj, class)
    local t = getclass(obj)
    while t do
        if t == class then return true end
        t = t.__super
    end
    return false
end
