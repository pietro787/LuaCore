--!strict
type ModuleInfo = {
    Name:string,
    Module:ModuleScript,
    Priority:number,
}

local Bootloader = {}

local Output = require("./Output")

local started = false
local bootOrder:{[string]:number} = {}
const AllowAfterStart = {
    "GetStatus"
}

local root:Folder?

function Bootloader.GetStatus():{string}
    return {""}
end

function Bootloader.CheckMap(map:{ModuleInfo})
    if not next(bootOrder) then return end
    
    for name, order in bootOrder do
        local found = false
        for _, info in map do
            if info.Name ~= name then continue end
            
            found = true
            break
        end

        if not found then
            Output.Warn(name.." not found", "Bootloader")
        end
    end
end

function Bootloader.MapModules():{ModuleInfo}
    if not root then 
        Output.Warn("Root must be set")
        return {}
    end

    local modules:{ModuleInfo} = {}

    for _, module in root:GetDescendants() do
        local name = module.Name
        if module and module:IsA("ModuleScript") then
            table.insert(modules, {
                Name = name,
                Priority = bootOrder[name] or 1,
                Module = module
            })
        end
    end

    Bootloader.CheckMap(modules)
    table.sort(modules, function(a0:ModuleInfo, a1:ModuleInfo): boolean  
        return a0.Priority > a1.Priority
    end)

    return table.freeze(modules)
end

function Bootloader.SetRoot(folder:Folder)
    root = folder
end

function Bootloader.SetBootOrder(modules:{[string]:number})
    bootOrder = modules
end

function Bootloader.Start(folder:Folder?)
    if started then return end
    started = true

    if not root and folder then
        Bootloader.SetRoot(folder)
    end

    const Modules = Bootloader.MapModules()
    for _, info in Modules do
        debug.profilebegin(info.Name)
        local requireSuccess, module = pcall(require, info.Module)

        if not requireSuccess then
            Output.Error(module, true, info.Name.." require")
            debug.profileend()
            continue
        end

        if typeof(module) ~= "table" then continue end
        if module.Load and typeof(module.Load) == "function" then
           local success, errmsg = pcall(module.Load)

            if not success then
                Output.Error(errmsg, true, info.Name.." 'Load'")
                debug.profileend()
                continue
            end 
        end

        if module.Start and typeof(module.Start) == "function" then
            local success, errmsg = pcall(module.Start)

            if not success then
                Output.Error(errmsg, true, info.Name.." 'Start'")
                debug.profileend()
                continue
            end
        end

        if module.Init and typeof(module.Init) == "function" then
            task.spawn(function()
                local success, errmsg = pcall(module.Init)

                if not success then
                    Output.Error(errmsg, true, info.Name.." 'Init'")
                    debug.profileend()
                    return
                end
            end)
        end

        debug.profileend()
    end 
end

return setmetatable({}, {
    __index = function(_, index)
        if started and not table.find(AllowAfterStart, index) then
            Output.Warn("Bootloader has already started")
            return function() end
        end

        return Bootloader[index]
    end
})