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

local select          = select
local pairs           = pairs
local ipairs          = ipairs
local type            = type
local next            = next
local tostring        = tostring
local tonumber        = tonumber
local print           = print
local pcall           = pcall
local os_date         = os.date
local os_time         = os.time
local debug_getinfo   = debug.getinfo
local debug_getlocal  = debug.getlocal
local debug_traceback = debug.traceback
local table_concat    = table.concat
local string_format   = string.format
local math_huge       = math.huge

local xeniclog = {
    enable        = true,
    filesrc       = 'short_src',
    namefields    = { 'name', 'what', 'namewhat' },
    missing       = '*',
    separator     = ' ',
    traceback     = true,
    timestamp     = os_time,
    innersuppress = false,
    innerlevel    = 0,
    innerprefix   = 'XENICLOG',
    funcmarkfmt   = '(%s) %s',
    stringmax     = 64,
    vfilter       = { self = true },
    filtermode    = true,
    timefilter    = false,
    timefilterstr = 0,
    timefilterend = math_huge,
    levelfilter   = { },
    prefixfilter  = { },
    filefilter    = { },

    -- tostruct   = tostring,
    -- printer    = print,
    -- logger     = print,
    -- funcmark   = print,
    -- override   = print,
}

local xllasterrmsg = { }

local function xltostring (v)
    local _, m = pcall(tostring, v)
    return m
end

local function xlpushmsgf (...)
    if xeniclog.innersuppress then return end
    xllasterrmsg[#xllasterrmsg + 1] = string_format(...)
end

local function xlchecklv (lv, off)
    if lv == nil then return off end
    local s = tonumber(lv)
    if not s or s < 0 then
        xlpushmsgf("incorrect level '%s', number expected", xltostring(lv))
        return off
    end
    return lv + off
end

local function xlgetfuncname (meta)
    for _, v in ipairs(xeniclog.namefields) do
        local n = meta[v]
        if n and n ~= '' then return n end
    end

    return xeniclog.missing
end

local function xlcheckapi (lv)
    if xeniclog.innersuppress or not next(xllasterrmsg) then return end

    local meta = debug_getinfo(lv + 1, 'nSl')
    local missing = xeniclog.missing
    local file, line, func
    if meta then
        file, line, func = meta[xeniclog.filesrc], meta.currentline, xlgetfuncname(meta)
    else
        file, line, func = missing, -1, missing
    end

    local printer = xeniclog.printer
    local time    = xeniclog.timestamp()
    local level   = xeniclog.innerlevel
    local prefix  = xeniclog.innerprefix
    for i, msg in ipairs(xllasterrmsg) do
        printer(time, level, prefix, file, line, func, msg, '')
        xllasterrmsg[i] = nil
    end
end

local function xldofilter (lv, level, prefix)
    local filtermode = xeniclog.filtermode

    if xeniclog.levelfilter[level] == filtermode then return end
    if xeniclog.prefixfilter[prefix] == filtermode then return end

    local meta = debug_getinfo(lv + 1, 'nSl')
    local file, line, func

    if meta then
        file = meta[xeniclog.filesrc]
        if xeniclog.filefilter[file] == filtermode then return end
        line, func = meta.currentline, xlgetfuncname(meta)
    else
        xlpushmsgf("stack info missing, checked by debug.getinfo(%d, 'nSl')", lv + 1)
        local missing = xeniclog.missing
        file, line, func = missing, -1, missing
    end

    local time = xeniclog.timestamp()

    if xeniclog.timefilter and type(filtermode) == 'boolean' then
        local inrange = xeniclog.timefilterstr <= time and time <= xeniclog.timefilterend
        if inrange ~= filtermode then return end
    end

    return time, file, line, func
end

local function xlstrizer (...)
    local argv = { ... }
    local tostruct = xeniclog.tostruct

    for i = 1, select('#', ...) do
        local v = argv[i]
        argv[i] = (type(v) ~= 'table' and xltostring or tostruct)(v)
    end

    return table_concat(argv, xeniclog.separator)
end

local function xlparamwarp (vfilter, name, value)
    local mode = vfilter[name]
    if mode == nil and type(value) ~= 'string' then mode = vfilter[value] end
    if mode then return end
    if mode == false then return nil, value, name end 

    if type(value) == 'table' then
        if next(value) then return name, value, name end
        return string_format('%s = { }', name)
    end

    local val = xeniclog.tostruct(value)
    if #val > xeniclog.stringmax or val:find('\n') then
        return name, value, name
    end

    return string_format('%s = %s', name, val)
end

local function xlinspeccaller (lv, vfilter)
    lv = lv + 1

    local curr = debug_getinfo(lv, 'nSu')
    if not curr then
        xlpushmsgf("stack info missing, checked by debug_getinfo(%d, '%s')", lv, 'nSu')
        return '<missing call stack info>'
    end

    local argvnames = { }
    local argvalues = { }
    for i = 1, curr.nparams do
        local name, value, valkey = xlparamwarp(vfilter, debug_getlocal(lv, i))
        if name ~= nil then argvnames[#argvnames + 1] = name end
        if value ~= nil then argvalues[valkey] = value end
    end

    if curr.isvararg then
        local passed
        for i = 1, math_huge do
            local key, val = debug_getlocal(lv, -i)
            if key == nil then break end
            passed = true
            local name, value, valkey = xlparamwarp(vfilter, ':v' .. i, val)
            if name ~= nil then argvnames[#argvnames + 1] = name end
            if value ~= nil then argvalues[valkey] = value end
        end
        if not passed then argvnames[#argvnames + 1] = '... = nil' end
    end

    local params = table_concat(argvnames, ', ')
    local values = next(argvalues) and xeniclog.tostruct(argvalues) or ''
    return string_format(xeniclog.funcmarkfmt, params, values)
end

-------------------------------------------------------------------------------

function xeniclog.tostruct (x)
    if type(x) ~= 'string' then return xltostring(x) end
    return string_format('%q', x)
end

function xeniclog.printer (time, level, prefix, file, line, func, msg, trace)
    local fmt = '[%s|%s|%s:%d#%s]: %s%s'
    local time = os_date('%H:%M:%S', time)
    return print(string_format(fmt, time, prefix, file, line, func, msg, trace))
end

function xeniclog.logger (level, prefix, lv, ...)
    if not xeniclog.enable then return end

    lv = xlchecklv(lv, 2)
    local time, file, line, func = xldofilter(lv, level, prefix)
    if not time then return end

    local msg = xlstrizer(...)
    local trace = xeniclog.traceback and debug_traceback('', lv) or ''

    xlcheckapi(2)
    return xeniclog.printer(time, level, prefix, file, line, func, msg, trace)
end

function xeniclog.funcmark (level, prefix, lv, _vfilter, ...)
    if not xeniclog.enable then return end

    lv = xlchecklv(lv, 2)
    local time, file, line, func = xldofilter(lv, level, prefix)
    if not time then return end

    if type(_vfilter) ~= 'table' then
        if type(_vfilter) ~= 'nil' then
            xlpushmsgf("_vfilter should be a table, got %s", type(_vfilter))
        end
        _vfilter = xeniclog.vfilter
    else
        for k, v in pairs(xeniclog.paramsfilter) do
            if _vfilter[k] == nil then _vfilter[k] = v end
        end
    end

    local proto = xlinspeccaller(lv, _vfilter)
    local extra = xlstrizer(...)
    local msg = string_format('%s%s%s', proto, xeniclog.separator, extra)
    local trace = xeniclog.traceback and debug_traceback('', lv) or ''

    xlcheckapi(2)
    return xeniclog.printer(time, level, prefix, file, line, func, msg, trace)
end

function xeniclog.override ( )
    local logger = xeniclog.logger
    local funcmark = xeniclog.funcmark
    local dump = {
        log         = function (...) return logger(0, 'V', 0, ...) end,
        xlfuncmark  = function (...) return funcmark(1, 'F', 0, nil, ...) end,
        xlfuncmark2 = function (vfilter, ...) return funcmark(1, 'F', 0, vfilter, ...) end,
        print       = function (...) return logger(2, 'I', 0, ...) end,
        warn        = function (...) return logger(3, 'W', 0, ...) end,
        error       = function (...) return logger(4, 'E', 0, ...) end,
        assertf     = function (cond, ...) if not cond then logger(5, 'A', 1, string_format(...)) end return cond, ... end,
    }
    
    for k, v in pairs(dump) do dump[k], _G[k] = _G[k], v end
    return xeniclog, dump
end

return xeniclog

--[[
xeniclog.override()
xeniclog.traceback = false

local function test (a, b, ...)
    log('debug message')
    print("information message")
    warn("warnning message")
    error("error message")
    assertf(false, "fail on %s", "custom assertf")
    xlfuncmark("extra params")
end

;(function (...)
    test(1, {2}, false, utf8, ...)
    xpcall(function(...)
        print("raising an error and handle by xlfuncmark()")
        print("the params is", ...)
        local dummy_foo = 'undefine_function' .. os.time()
        dummy_foo()
    end, xlfuncmark, ...)
end)("inspecting xeniclog setting value =>", xeniclog)
--]]

--[[ -- output:
/sdcard/1/karx3l $luax xeniclog.lua
[09:12:02|V|xeniclog.lua:284#test]: debug message
information message
[09:12:02|W|xeniclog.lua:286#test]: warnning message
[09:12:02|E|xeniclog.lua:287#test]: error message
[09:12:02|A|xeniclog.lua:288#test]: fail on custom assertf
[09:12:02|F|xeniclog.lua:289#test]: (a = 1, b, :v1 = false, :v2, :v3 = "inspecting xeniclog setting value =>", :v4) table: 0x710747e840 extra params
raising an error and handle by xlfuncmark()
the params is   inspecting xeniclog setting value =>    table: 0x710745ef00
[09:12:02|F|xeniclog.lua:298#Lua]: (:v1 = "inspecting xeniclog setting value =>", :v2) table: 0x710747ea00 xeniclog.lua:298: attempt to call a string value (local 'dummy_foo')
--]]
