CONFIG_PATH = "/etc/users.lua"

local function loadConfig(path)
    if not fs.exists(path) then
        return nil, "Config does not exist"
    end

    local config, err = loadfile(path)()
    if config == nil then
        return nil, "Config is not a Lua file \n"..err
    end

    if type(config.users) == "table" then
        for name, user in pairs(config.users) do
            if type(name) ~= "string" then
                return nil, "User name \""..name.."\" is not a string"
            end

            if type(user.password) ~= "string" then
                return nil, "Password for user \""..name.."\" is not a string"
            end

            if type(user.uid) ~= "number" then
                return nil, "uid flag for user \""..name.."\" must be a number"
            end

            if user.shell ~= nil and type(user.shell) ~= "string" then
                return nil, "Shell for user \""..name.."\" is not a string"
            end
        end
    end

    return config
end

local function main()
    local config, err = loadConfig(CONFIG_PATH)

    if config == nil then
        printError("Login config is malformed or empty.\n"..err)
    end

    while true do
        term.write("Username: ")
        local username = read()
        term.write("Password: ")
        local password = read("*")

        local user = config.users[username]

        local error = false
        if user == nil or password ~= user.password then
            printError("Incorrect username or password")
            error = true
        end

        if not error then
            local name = user.uid.."#shell"
            local userShell = user.shell or "/rom/programs/shell.lua"
            process.spawn(name, userShell, user.uid)
            process.waitJob(name)
        end
    end
end

local ok, err = pcall(main)
if not ok then
    if debug and debug.traceback then
        printError("Login system crash: " .. debug.traceback(err))
    else
        printError("Login system crash: " .. tostring(err))
    end
end
