-- Prevent the shell from recursively spawning us.
-- In CC, the shell is responsible for running startup.lua
if _G._INIT_SKIP_STARTUP then
    return
end

CONFIG_PATH = "/etc/init/services.lua"

local ProcessManager = {
    processes = {},
}

function ProcessManager.makeEnv(name, guid)
    local sProcess = {
        list = function ()
            local count = 0
            local result = {}

            for lName, process in pairs(ProcessManager.processes) do
                result[lName] = {
                    name = lName,
                    uid = process.uid,
                    path = process.path
                }
                count = count + 1
            end

            return count, result
        end,
        getUid = function ()
            return guid
        end,
        getJobName = function ()
            return name
        end,
        setUid = function (uid)
            if guid ~= uid and guid ~= 0 then
                error("Permission denied: user #"..guid.." is not allowed to change effective user id")
            end
            ProcessManager.processes[name].uid = uid
        end,
        spawn = function (name, path, uid)
            if guid ~= uid and guid ~= 0 then
                error("Permission denied: user #"..guid.." is not allowed to change effective user id")
            end
            if ProcessManager.processes[name] ~= nil then
                error("Process with name \""..name.."\" already exists")
            end

            ProcessManager.spawn({
                name = name,
                path = path,
                uid = uid
            })
        end,
        waitJob = function (name)
            while true do
                if ProcessManager.processes[name] == nil then
                    break
                end
                coroutine.yield()
            end
        end
    }

    local env = setmetatable({}, { __index = _ENV })
    env.process = sProcess
    env.multishell = multishell

    env._INIT_SKIP_STARTUP = true
    env._G = env
    return env
end

function ProcessManager.spawn(job)
    local name = job.name
    local path = job.path
    local restart = job.restart
    local uid = job.uid or 0

    local function supervisor()
        local env = ProcessManager.makeEnv(name, uid)
        local ok, err = pcall(function() os.run(env, path) end)
        if not ok then
            if debug and debug.traceback then
                printError("process #"..name.." crash: " .. debug.traceback(err))
            else
                printError("process #"..name.." crash: " .. tostring(err))
            end
        end
    end

    local process = {
        name = name,
        uid = uid,
        path = path,
        thread = coroutine.create(supervisor),
        restart = restart
    }

    ProcessManager.processes[name] = process

    coroutine.resume(process.thread)
end

local function requestShutdown()
    print("Provide any input to power down.")

    while true do
        local event = os.pullEventRaw()
        if event == "char" or event == "key" then
            break
        elseif event == "terminate" then
            break
        end
    end

    os.shutdown()
end

local function loadConfig(path)
    if not fs.exists(path) then
        return nil, "Config does not exist"
    end

    local config, err = loadfile(path)()
    if config == nil then
        return nil, "Config is not a Lua file \n"..err
    end

    if type(config.jobs) == "table" then
        for name, job in pairs(config.jobs) do
            if type(name) ~= "string" then
                return nil, "Job name \""..name.."\" is not a string"
            end

            if type(job) ~= "table" then
                return nil, "Job definition \""..name.."\" is not a table"
            end

            if type(job.path) ~= "string" then
                return nil, "Path for job \""..name.."\" is not a string"
            end

            if job.restart ~= nil and type(job.restart) ~= "string" then
                return nil, "Restart flag for job \""..name.."\" is not a string"
            end

            if job.restart ~= nil and job.restart ~= "always" then
                return nil, "Restart flag for job \""..name.."\" can only be \"always\""
            end

            if job.uid ~= nil and type(job.uid) ~= "number" then
                return nil, "uid flag for job \""..name.."\" must be a number"
            end
        end
    end

    return config
end

local function main()
    term.setCursorPos(1, 1)
    term.clear()

    local config, err = loadConfig(CONFIG_PATH)

    if config == nil then
        printError("Init config is malformed or empty, using default.\n"..err)
        local job = {
            name = "shell",
            path = "/rom/programs/shell.lua"
        }
        ProcessManager.spawn(job)
    else
        if config.jobs then
            for name, job in pairs(config.jobs) do
                ProcessManager.spawn({
                    name = name,
                    path = job.path,
                    restart = job.restart,
                    uid = job.uid
                })
            end
        end
    end

    while true do
        local event = table.pack(os.pullEventRaw())

        for name, job in pairs(ProcessManager.processes) do
            local thread = job.thread

            coroutine.resume(thread, table.unpack(event))

            local terminated = false
            if coroutine.status(thread) == "dead" then
                terminated = true
            end

            if terminated then
                printError("Terminated job #"..name)
                ProcessManager.processes[name] = nil
            end

            if terminated and job.restart == "always" then
                print("Restarting job #"..name)
                local ogJob = config.jobs[name]
                ProcessManager.spawn({
                    name = name,
                    path = ogJob.path,
                    restart = ogJob.restart,
                    uid = ogJob.uid
                })
            end
        end
    end
end

local ok, err = pcall(main)
if not ok then
    if debug and debug.traceback then
        printError("Init system crash: " .. debug.traceback(err))
    else
        printError("Init system crash: " .. tostring(err))
    end
end

requestShutdown()
