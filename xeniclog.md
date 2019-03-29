# Xeniclog.lua
**Xeniclog.lua** is a log tool (**XL**). It collects information about file name, line number, function name and time
then logging and filtering.

Using the Function Markup Method (xeniclog.funcmark()), a simple function call can automatically print out the called
parameter information, see the [detailed](#for_example) at the below.
XL has a log printer interface, so that you can put it to standard output (default), file, e-mail,
and even network after log processing completed.

**XL uses the Lua standard library debug to gather the necessary information and format it, which can result 
in a loss of performance.**

The operation methods and settings for XL come from one table returned by `require("xeniclog")`.

##### Basic usage:
```Lua
-- require xeniclog and overrides the original log function in _G.
require("xeniclog").override()
```

#### Methods
`xeniclog.logger(level, prefix, lv, ...)`
> Output a log. return the value return by xeniclog.printer().
  `level`: log level, any type, passed to xeniclog.printer() without modification
  `prefix`: log prefix, any type, passed to xeniclog.printer() without modification
  `lv`: the level of the stack information, 0 means start with xeniclog.logger()
  `...` specific log content, stringed then passed to xeniclog.printer().

`xeniclog.funcmark(level, prefix, lv, _vfilter, ...)`
> Output called information and additional log. return the value return from xeniclog.printer().
  `level`: log level, any type, passed to xeniclog.printer() without modification
  `prefix`: log prefix, any type, passed to xeniclog.printer() without modification
  `lv`: the level of the stack information, 0 means start with xeniclog.logger()
  `_vfilter`: parameter filter, nil means only use xeniclog.vfilter,
    otherwise it should be a table and will be modified to merging from xeniclog.vfilter.
  `...` additional log content, stringed then passed to xeniclog.printer().

`xeniclog.override()`
> Create default common use log output methods in _G. return the xeniclog and a table
  stored in the corresponding old method in _G.
    `log(...)`
    `xlfuncmark(...)`
    `xlfuncmark2(vfilter, ...)`
    `print(...)`
    `warn(...)`
    `error(...)`
    `assertf(cond, fmt, ...)`
> These methods all return the value return by xeniclog.printer(), except assertf() which always returns the value passed to it.

#### Settings
`xeniclog.enable = true`
> Enable xeniclog log output.

`xeniclog.filesrc = 'short_src'`
> The field name as file name return from debug.traceback(), which can be short_src, source, name, namewhat, what, etc.

`xeniclog.namefields = { 'name', 'what', 'namewhat' }`
> The field names as function name return from debug.traceback(), the first name not empty is used.

`xeniclog.missing = '*'`
> Alternative name when debug.traceback() is not available or field is missing. the line number is -1 if missing.

`xeniclog.separator = ' '`
> Separator when logging one more variables.

`xeniclog.traceback = true`
> Collect traceback information, empty for not set.

`xeniclog.timestamp = os.time`
> Timestamp method, no arguments, return an integer.

`xeniclog.innersuppress = false`
> Suppress xeniclog internal diagnostic log.

`xeniclog.innerlevel = 0`
> Log level of xeniclog internal diagnostic log.

`xeniclog.innerprefix = 'XENICLOG'`
> Log prefix of xeniclog internal diagnostic log.

`xeniclog.funcmarkfmt = '(%s) %s'`
> Function called mark format pattern, the first placeholder for the actual parameter summary string,
and the second for the actual parameter details.

`xeniclog.stringmax = 64`
> Maximum length of a single argument in the function called mark actual parameter summary string. beyond this length,
is placed in the actual argument details.

`xeniclog.vfilter  = { self = true }`
> Parameter filter for Function called mark. If the key is a string, the parameter name is filtered,
otherwise the value of the actual parameter is filtered. If the value is true it will be discarded,
for false it will be placed in the actual parameter details.

`xeniclog.filtermode = true`
> Filter mode, the log is discarded when it matches the value in any filters.

`xeniclog.timefilter = false`
> Enable the timestamp filter.

`xeniclog.timefilterstr = 0`
> Timestamp of timestamp filter startup.

`xeniclog.timefilterend = math.huge`
> Timestamp of timestamp filter termination.

`xeniclog.levelfilter   = { }`
> Log level filter, the key is the level, and the value is the filter mode. Level can be any valid value.

`xeniclog.prefixfilter  = { }`
> Log prefix filter, the key is the prefix, and the value is the filter mode. Prefix can be any valid value.

`xeniclog.filefilter    = { }`
>.Log file name filter, the key is the file name, and the value is the filter mode. File name is usually a string.

`xeniclog.tostruct`
> Convert an variable (any type) to a structured string, one parameter and return a string.
  `function tostruct(var: any) : any`

`xeniclog.printer`
> Print the contents of the specific log. the return value will be returned by xeniclog.logger().

> `function printer(
  time: time_val,
  level: user_val,
  prefix: user_val, 
  file: string,
  line: integer,
  func: string,
  msg: string,
  traceback: string) : user_val`

>**time_val** is determined by xeniclog.timestamp(), **user_val** is determined by the user.
The number and type of return values are determined by the user.

[](#for_example)
#### For Example
```Lua
require("xeniclog").override()

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
```
```shell
# output:
/sdcard/1/karx3l $luax xeniclog.lua
[09:12:02|V|xeniclog.lua:284#test]: debug message
information message
[09:12:02|W|xeniclog.lua:286#test]: warnning message
[09:12:02|E|xeniclog.lua:287#test]: error message
[09:12:02|A|xeniclog.lua:288#test]: fail on custom assertf
[09:12:02|F|xeniclog.lua:289#test]: (a = 1, b, :v1 = false, :v2, 
    :v3 = "inspecting xeniclog setting value =>", :v4)
table: 0x710747e840 extra params
raising an error and handle by xlfuncmark()
the params is   inspecting xeniclog setting value =>    table: 0x710745ef00
[09:12:02|F|xeniclog.lua:298#Lua]: (:v1 = "inspecting xeniclog setting value =>", :v2)
    table: 0x710747ea00
xeniclog.lua:298: attempt to call a string value (local 'dummy_foo')
```
