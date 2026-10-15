local LuaCore = {}

local Bootloader = require("@self/Bootloader")
local Interface = require("@self/Classes/Interface")

function LuaCore:CreateUI(callback, vide)
    return Interface.new(vide):Create(callback)
end

function LuaCore:Tag(tagName:string)
    
end

-- Bootloade vai dar require nos modules de UI
-- Dps de dar os requires eles vão chamar "NewInterface"
-- Dps começa a criar as UIs

type LuaCoreType = {
    CreateUI:(LuaCoreType, callback:Interface.BuildFunction, vide:any) -> (Interface.ClassType),
    Tag:(LuaCoreType, tagName:string) -> (),
} & Bootloader.PublicFunctions & (folder:Folder?) -> ()

return (setmetatable(LuaCore, {
    __index = function(_, index)
        if typeof(index) ~= "string" then return end
      --  if not PublicFunctions.Bootloader[index] then return end
    
        return Bootloader[index]
    end,

    __call = function(_, param)
        Bootloader.Start(param)
    end
}) :: LuaCoreType)
