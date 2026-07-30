# SystemLC "System Lua Control"

SystemLC is a modern initialization system for ComputerCraft and CC: Tweaked is designed to provide a system to manage multiple jobs operating in parallel and user session managers, allowing for the creation of a multi-user time-sharing environment. It is designed to be modular and extensible, allowing you to define your own jobs and user sessions.

## Jobs

Jobs are the fundamental units of work in SystemLC. Each job represents a distinct task that can be executed in parallel with other jobs.

Jobs are defined in the `/etc/init/services.lua` file. The shape of this file is as follows:

```lua
{
    jobs = {
        "job_name" = { -- the name of the job, used to identify it in the job manager
            path = "path/to/job.lua", -- the path to the job's main script
            restart = "always" | nil, -- whether the job should be restarted if it exits, if not specified, the job will not be restarted
            uid = "number" | nil, -- the user ID to run the job as, if not specified, the job will run as root (uid 0)
        },
    }
}
```

## User Sessions

SystemLC does not manage user session it self. Instead it assigns uids to processes and allows for user session managers to be defined as jobs.

A user session manager is a job that manages the login and logout of users, and can spawn user shells or other processes as needed.

### SystemLC Login Manager

SystemLC provides a login manager that can be used to manage user sessions. The login manager is defined as a job in the `/etc/init/services.lua` file, and can be configured to spawn user shells or other processes as needed.

Users are defined in the `/etc/users.lua` file. The shape of this file is as follows:

```lua
{
    users = {
        "username" = { -- the username of the user, used to identify them in the login manager
            uid = "number", -- the user ID of the user, used to assign uids to processes spawned by the user
            password = "string", -- the password of the user, used to authenticate them in the login manager
            shell = "path/to/shell.lua" | nil, -- the path to the user's shell, used to spawn a shell for the user when they log in. Defaults to /rom/programs/shell.lua if not specified
        },
    }
}
```

*Example user configuration is provided at [./examples/users.lua](./examples/users.lua)*

## Installation

### Minimal installation

SystemLC can be installed by:
1. copying the [`systemlc.lua](./systemlc.lua) file to `/bin/systemlc.lua` 
2. define a minimal job configuration to provide your shell:

```lua
{
    jobs = {
        "shell" = {
            path = "/rom/programs/shell.lua",
            restart = "always",
        },
    }
}
``` 
3. prepend systemlc.lua to `/startup.lua` to start SystemLC on boot:

```lua
shell.run("/bin/systemlc.lua")
```

---

This minimal installation provides just the job manager without any SystemLC utilities or user session management.

#### Utility installation

The initial release of SystemLC provides a single `ps.lua` utility to list the currently running jobs. This utility can be installed by copying the [`ps.lua`](./ps.lua) file to `/bin/ps.lua`.

#### Login Manager Installation

The login manager can be installed by:
1. copying the [`login.lua`](./login.lua) file to `/bin/login.lua`
2. replacing the default shell job in `/etc/init/services.lua` with the login manager job: *Example provided at [./examples/services.lua](./examples/services.lua)*
3. defining users in `/etc/users.lua` as described above.

## Process API

Any process spawned by SystemLC will have the `process` API injected into its global environment. This API provides a set of functions to manage the process, including:

| Function | Description |
|----------|-------------|
| `process.getUid() -> number` | Returns the uid of the process |
| `process.getJobName() -> string` | Returns the name of the job that spawned the process |
| `process.setUid(uid: number) -> nil` | Sets the uid of the process. Can only be used by root. If the requested uid is the same as the current uid, the function will do nothing. |
| `process.spawn(name: string, path: string, uid: number) -> nil` | Spawns a new process with the given name, path, and uid. The new process will be spawned as a child of the current process. Can be used by any user, except when spawning processes with a different uid, which requires root privileges. |
| `process.waitJob(name: string) -> nil` | Waits for the job with the given name to exit. Can be used by any user. |
