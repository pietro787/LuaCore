--!strict
type ValidPath = Folder
export type PublicFunctions = {
    GetStatus:() -> ({string}),
    SetModuleOrder:(moduleName:string, priority:number) -> (),
    AddIgnoredPath:(path:Folder|ModuleScript|string, timeout:number?) -> (),
    SetRoot:(root:Folder) -> ()
}

type ModuleInfo = {
    Name:string,
    Module:ModuleScript,
    Priority:number,
}

local Bootloader = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Output = require("./Output")
local Interface = require("./Classes/Interface")
local Vide = require("./libs/vide") :: Interface.Vide
local WaitForDescendant = require("./Utils/WaitForDescendant")
local WaitFor = require("./Utils/WaitFor")

local started = false
local uiStarted = false

local bootOrder:{[string]:number} = {}
local excludedPaths:{[string]:Folder|ModuleScript} = {}
const PublicFunctions = {
    "SetModuleOrder",
    "GetStatus",
    "SetRoot",
    "AddIgnoredPath"
}

const AllowAfterStart = {
    "GetStatus"
}

local root:Folder?

local function GetLocalPlayer():Player?
    return RunService:IsClient() and Players.LocalPlayer or nil
end

function Bootloader.AddIgnoredPath(path:Folder|ModuleScript|string, timeout:number?)
    local function CheckPathType(instance:Instance):boolean
        if not instance:IsA("Folder") and not instance:IsA("ModuleScript") then
            Output.Warn("path must be a 'Folder' or 'ModuleScript' in 'AddIgnoredPath'", "Bootloader")
            return false
        end

        return true
    end
    
    if typeof(path) == "string" then
        if not root then
            Output.Warn("(AddIgnoredPath) root must be set", "Bootloader")
            return
        end

        local instance = (root:IsDescendantOf(ReplicatedStorage) or RunService:IsServer()) and root:FindFirstChild(path, true) or WaitForDescendant(root, path, timeout)
        if not instance then
            Output.Warn(path.." not found in 'AddIgnoredPath'.", "Bootloader")
            return
        end

        if not CheckPathType(instance) then return end
        excludedPaths[path] = instance :: ValidPath
        return
    elseif typeof(path) == "Instance" then
        if CheckPathType(path) then
            excludedPaths[path.Name] = path
            return
        end
    end
end

function Bootloader.GetStatus():{string}
    return {""}
end

function Bootloader.CheckMap(map:{ModuleInfo})
    if not next(bootOrder) then return end
    
    for name, _ in bootOrder do
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
    local function IsExcluded(module:ModuleScript):boolean
        local target = excludedPaths[module.Name]
        if target and target:IsA("ModuleScript") then
            return true
        end

        for name, instance in excludedPaths do
            if instance:IsA("Folder") then
                if not module:IsDescendantOf(instance) then continue end
                return true
            end

            if instance == module then
                return true
            end
        end

        return false
    end

    if not root then 
        Output.Warn("(Start) Root must be set", "Bootloader")
        return {}
    end

    local modules:{ModuleInfo} = {}
    for _, module in root:GetDescendants() do
        local name = module.Name
        if module and module:IsA("ModuleScript") then
            if IsExcluded(module) then continue end
            table.insert(modules, {
                Name = name,
                Priority = math.max(bootOrder[name] or 1, 1),
                Module = module
            })
        end
    end

    --Bootloader.CheckMap(modules)
    table.sort(modules, function(a0:ModuleInfo, a1:ModuleInfo): boolean  
        return a0.Priority > a1.Priority
    end)

    return table.freeze(modules)
end

function Bootloader.SetRoot(folder:Folder)
    root = folder
end

function Bootloader.SetModuleOrder(moduleName:string, priority:number)
    if typeof(priority) ~= "number" then Output.Warn("(SetModuleOrder) priority must be a number"); return end
    if typeof(moduleName) ~= "string" then Output.Warn("(SetModuleOrder) moduleName must be a string"); return end
    if not bootOrder then
        bootOrder = {}
    end

    bootOrder[moduleName] = math.max(priority, 1)
end

function Bootloader.Start(folder:Folder?)
    if not RunService:IsRunning() then return end
    if started then return end
    started = true

    if not root and folder then
        Bootloader.SetRoot(folder)
    end

    const Modules = Bootloader.MapModules()
    local uiModules = {}

    for _, info in Modules do
        debug.profilebegin(info.Name.. " require")
        local requireSuccess, module = pcall(require, info.Module)

        if not requireSuccess then
            Output.Error(module, true, info.Name.." require")
            debug.profileend()
            continue
        end

        if typeof(module) ~= "table" then 
            debug.profileend()
            continue
        end
        
        debug.profileend()

        if module.Load and typeof(module.Load) == "function" then
            debug.profilebegin(info.Name.. " load")
            local success, errmsg = pcall(module.Load)

            if not success then
                Output.Error(errmsg, true, info.Name.." 'Load'")
                debug.profileend()
                continue
            end 

            debug.profileend()
        end

        if module.Start and typeof(module.Start) == "function" then
            debug.profilebegin(info.Name.. " start")
            local success, errmsg = pcall(module.Start)

            if not success then
                Output.Error(errmsg, true, info.Name.." 'Start'")
                debug.profileend()
                continue
            end

            debug.profileend()
        end

        if module.Init and typeof(module.Init) == "function" then
            task.spawn(function()
                debug.profilebegin(info.Name.. "init")
                local success, errmsg = pcall(module.Init)

                if not success then
                    Output.Error(errmsg, true, info.Name.." 'Init'")
                    debug.profileend()
                    return
                end

                debug.profileend()
            end)
        end

        if module.Build and typeof(module.Build) == "table" then
            table.insert(uiModules, module)
        end
    end

    task.defer(function()
        if RunService:IsClient() then
            Bootloader.StartUIs(uiModules::any)
        end
    end)
end

function Bootloader.StartUIs(uiModules:{[number]:{Build:Interface.ClassType, Name:string?}})
    if RunService:IsServer() then return end
    if not RunService:IsRunning() then return end
    if uiStarted then return end
    uiStarted = true

    local Player = GetLocalPlayer()
    if not Player then
        Output.Error("'LocalPlayer' not found.", true, "Bootloader")
        return
    end

    local _root = Vide.root
    local create = Vide.create
    local action = Vide.action

    create "ScreenGui" {
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        Parent = Player:WaitForChild("PlayerGui"),
        Name = "LuaCore_ScreenGui",

        action(function(screeGui)
            local AllInterfaces = {}

            for _, module in uiModules do
                local moduleInterface = module.Build

                if not moduleInterface._Instance then
                    WaitFor(function(instance)
                        if typeof(moduleInterface._Instance) ~= "Instance" then return end
                        moduleInterface._Instance.Name = module.Name or moduleInterface._Instance.ClassName
                        moduleInterface._Instance.Parent = screeGui
                    end, moduleInterface._Instance, 2)
                    :OnTimeout(function()
                        Output.Warn("the interface took too long to load", "Bootloader")
                    end)

                    continue
                end
                
                if moduleInterface._Instance:IsA("GuiBase2d") then
                    moduleInterface._Instance.Name = module.Name or moduleInterface._Instance.ClassName
                    table.insert(AllInterfaces, moduleInterface._Instance)
                end
            end
        
            for _, interface in AllInterfaces do
                interface.Parent = screeGui
            end
        end)
    }
    
end

return setmetatable({}, {
    __index = function(_, index)
        if started and not table.find(AllowAfterStart, index) then
            Output.Warn("Bootloader has already started")
            return function() end
        end

        if not table.find(PublicFunctions, index) then
            return function() end
        end

        return Bootloader[index]
    end
})