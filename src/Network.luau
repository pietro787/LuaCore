local Network = {}

local RunService = game:GetService("RunService")

local Output = require("./Output")

local loadOrder = {}
local callbacks = {}
local loaded = false

local rootFolder:Folder

local function ExecuteStart()
    for _, callback in callbacks do
        local sucess, err = pcall(callback)

        if not sucess then
            Output.Warn("Callback error. Error:"..err, "Newtwork")
        end
    end
end

function Network.GenerateOrder(root:Folder?)
    if RunService:IsClient() then return end
    if next(loadOrder) then return end
    if not rootFolder and root then
        rootFolder = root
    end

    if root then
        for _, module in rootFolder:GetChildren() do
            if not module:IsA("ModuleScript") then continue end
            local sucess, err = pcall(require, module)

            if not sucess then
                Output.Warn(module.Name.." require error. "..err, "Network")
                continue
            end

            table.insert(loadOrder, module.Name)
        end

        ExecuteStart()
    else
        Output.Warn("root is nil", "Network")
    end
end

function Network.SetRoot(folder:Folder)
    if typeof(folder) ~= "Folder" then return end
    if not folder:IsA("Folder") then return end

    rootFolder = folder
end

function Network.OnStart(callback)
    table.insert(callbacks, callback)
end

function Network.Init()
    if loaded then return end
    loaded = true

    local Event:RemoteEvent

    if RunService:IsServer() then
        Event = Instance.new("RemoteEvent")
        Event.Parent = script.Parent

        Event.OnServerEvent:Connect(function(player: Player, ...)
            if not rootFolder then
                Output.Warn("root is nil", "Network")
                return
            end

            if next(loadOrder) then
                (Event::RemoteEvent):FireClient(player, loadOrder)
                return
            end

            Event:FireClient(player, Network.GenerateOrder())
        end)
    else
        Event = script.Parent:WaitForChild("RemoteEvent", 15)

        if not Event or not Event:IsA("RemoteEvent") then
            Output.Error("LuaCore must be require at server and client")
            return
        end

        Event:FireServer()
        Event.OnClientEvent:Connect(function(order)
            if typeof(loadOrder) ~= "table" then return end
            if next(loadOrder) then return end
            if not rootFolder then 
                Output.Warn("root is nil", "Network")
                return 
            end

            for _, packetName in order do
                if typeof(packetName) ~= "string" then continue end

                local module = rootFolder:WaitForChild(packetName, 2)
                if not module:IsA("ModuleScript") then continue end
                
                local sucess, err = pcall(require, module)
                if not sucess then
                    Output.Warn(module.Name.." require error. "..err, "Network")
                    continue
                end

                table.insert(loadOrder, module.Name)
            end

            ExecuteStart()
        end)
    end
end

return Network