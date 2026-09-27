
local LuaCore = {}

local Bootloader = require("@self/Bootloader")
local Interface = require("@self/Classes/Interface")

function LuaCore.NewInterface(vide)
    local NewInterface = Interface.new(vide)
    
    
    return NewInterface
end

function LuaCore:Tag(tagName:string)
    
end

-- Bootloade vai dar require nos modules de UI
-- Dps de dar os requires eles vão chamar "NewInterface"
-- Dps do começa a criar as UIs

type LuaCoreType = {
    NewInterface:(vide:any) -> (Interface.ClassType),
    Tag:(LuaCoreType, tagName:string) -> ()
} & (folder:Folder?) -> ()

return setmetatable(LuaCore, {
    __call = function(_, param)
        Bootloader.Start(param)
    end
}) :: LuaCoreType
