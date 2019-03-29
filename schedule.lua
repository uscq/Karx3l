--[[
Copyright (c) 2016-2019 uscq <yuleader@163.com> All rights reserved.

Licensed under the MIT License (the "License"); you may not use this file except
in compliance with the License. You may obtain a copy of the License at
  http://opensource.org/licenses/MIT
Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations.
--]]

local type = type
local next = next
local pcall = pcall
local pairs = pairs
local assert = assert
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local coroutine_yield  = coroutine.yield
local coroutine_running = coroutine.running

local schedule_error = print
local schedule_idles = { }
local schedule_stash = { }
local schedule_pairs = { }

local function auxiliary (entrance)
    repeat
        entrance()
        schedule_idles[coroutine_running()] = true
        entrance = coroutine_yield()
    until not entrance
end

local function alloc ( )
    local co = next(schedule_idles)

    if co then
        schedule_idles[co] = nil
    else
        co = coroutine_create(auxiliary)
    end

    return co
end

local function start (func)
    local co = alloc()
    assert(coroutine_resume(co, func))
    return co
end

local function wait (sec)
    if not sec then sec = 0 end
    assert(type(sec) == 'number', 'number expect')
    local co, main = coroutine_running()
    assert(not main, 'can not wait on main coroutine')
    schedule_stash[co] = sec
    coroutine_yield()
end

local function stop (co)
    local checked = coroutine_status() == "suspended"
    assert(checked, "not a suspended coroutine")
    schedule_stash[co] = nil
    schedule_pairs[co] = nil
    schedule_idles[co] = true
end

local function update (delta)
    for k, v in pairs(schedule_stash) do
        schedule_stash[k] = nil
        schedule_pairs[k] = v
    end

    for co, sec in pairs(schedule_pairs) do
        sec = sec - delta
        if sec <= 0 then
            sec = nil
            assert(coroutine_resume(co))
        end
        schedule_pairs[co] = sec
    end
end

return {
    -- @brief create a schedule handler (corountine) from pool
    -- @note the result corountine is a wrapped corountine that
    --    diff from standard coroutine.create().
    --    That is, when calling coroutine.resume() with the wrapped
    --    corountine return by alloc(), it does not take extra agruments.
    --    After first call on resume(), it is a standard corountine to resume()/yield().
    --
    --    For example:
    --        local co = alloc()
    --        coroutine.resume(co, print, 'a', 'b') -- you got a blank line
    --
    --        local co2 = coroutine.create(print)
    --        coroutine.resume(co2, 'a', 'b') -- you got "a b"
    alloc = alloc, -- () => coroutine

    -- @brief start a schedule of function
    --     that is call @see alloc() and resume it.
    -- @param func[in, function]: the entrance of thread
    -- @return corountine-type
    start = start, -- (func) => coroutine

    -- @brief suspend current corountine/schedule for sec second(s).
    -- @param sec[in, number]: second to wait, option is 0.
    -- @note it may yield at least one time of the update.
    wait = wait, -- (sec) => nil

    -- @brief stop a corountine/schedule
    -- @param co[in, corountine]: it should be the value return from @see start(func)
    --    it also works on any corountine that coroutine.status() return "suspended".
    stop = stop, -- (co) => nil

    -- @brief the heartbeat of the schedules
    -- @param delta[in, number]: the second from last call of the update().
    update = update, -- (delta) => nil

    -- @brief alias of standard coroutine.yield()
    yield = coroutine_yield,

    -- @brief alias of standard coroutine.resume()
    resume = coroutine_resume,
}


--[[
-- For example:

local luv = require "luv"
local schedule = require "schedule"

local fps = 30
local frame = 0
local delta = 1 / fps
local interval =  math.floor(delta * 1000)

luv.new_timer():start(interval, interval, function()
    frame = frame + 1
    schedule.update(delta)
end)

schedule.start(function()
    print("frame:", frame)
    print("co info:", coroutine.running())

    schedule.wait(1.3)
    print("after 1.3 seconds, frame is", frame)

    local leftsec = 15
    repeat
        print("time left", leftsec, "second(s).")
        schedule.wait(1)
        leftsec = leftsec - 1
    until leftsec <= 0
    print("done.")
    
    schedule.stop(coroutine.running())
    print("you can see this after stop() inside.")

    schedule.wait()
    print("and this after wait() inside.")
    
    -- you can NOT stop schedule inside before it go to end
    -- but call schedule.stop() with the value return from schedule.start() out of the body
    return
end)
--]]
