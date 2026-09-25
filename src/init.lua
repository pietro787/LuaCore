
local LuaCore = {}

local Bootloader = require("@self/Bootloader")
local Interface = require("@self/Classes/Interface")

function LuaCore.NewInterface(vide)
    return Interface.new(vide)
end

function LuaCore:Tag(tagName:string)
    
end

type LuaCoreType = {
    NewInterface:(vide:any) -> (Interface.ClassType),
    Tag:(LuaCoreType, tagName:string) -> ()
} & (folder:Folder?) -> ()

return setmetatable(LuaCore, {
    __call = function(_, param)
        Bootloader.Start(param)
    end
}) :: LuaCoreType
