--!strict
type ModuleInfo = {
    Name:string,
    Module:ModuleScript,
    Priority:number,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Bootloader = {}

local Output = require("./Output")
local Interface = require("./Classes/Interface")
local Vide = require("./libs/vide")

local started = false
local uiStarted = false

local bootOrder:{[string]:number} = {}
const AllowAfterStart = {
    "GetStatus"
}

local create = Vide.create
local videRoot = Vide.root

local root:Folder?

local function GetLocalPlayer():Player?
    return RunService:IsClient() and Players.LocalPlayer or nil
end

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
    local uiModules = {}

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

        if module.Build and typeof(module.Build) == "table" then
            table.insert(uiModules, module)
        end

        debug.profileend()
    end

    task.defer(function()
        if RunService:IsClient() then
            Bootloader.StartUIs(uiModules::any)
        end
    end)
end

function Bootloader.StartUIs(uiModules:{Build:Interface.ClassType, [string]:any})
    if RunService:IsServer() then return end
    if uiStarted then return end
    uiStarted = true

    local Player = GetLocalPlayer()
    if not Player then
        Output.Error("'LocalPlayer' not found.", true, "Bootloader")
        return
    end

    videRoot(function()
        local ScreenGui
        ScreenGui = create "ScreenGui" {
            ResetOnSpawn = false,
            Parent = Player:WaitForChild("PlayerGui"),
            Name = "LuaCore_ScreenGui",
            function()
                local AllInterfaces = {}
                for _, module in uiModules do
                    local moduleInterface = module.Build
                    if not moduleInterface.Instance then
                        task.spawn(function()
                            local waited = 0
                            while not moduleInterface.Instance do
                                task.wait(0.1)
                                waited += 0.1

                                if waited >= 2 then
                                    Output.Warn("the interface took too long to load", "Bootloader")
                                    break
                                end
                            end

                            if moduleInterface.Instance and typeof(moduleInterface.Instance) == "Instance" then
                                moduleInterface.Instance.Parent = ScreenGui
                            end
                        end)

                        continue
                    end
                    
                    if typeof(moduleInterface.Instance) == "Instance" then
                        table.insert(AllInterfaces, moduleInterface.Instance)
                    end
                end

                return table.unpack(AllInterfaces)
            end
        }
    end)
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