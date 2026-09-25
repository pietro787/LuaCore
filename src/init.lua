local LuaCore = {}

local Bootloader = require("@self/Bootloader")
local Interface = require("@self/Classes/Interface")

function LuaCore.NewInterface(vide)
    return Interface.new(vide)
end

return setmetatable(LuaCore, {
    __call = function(_, param)
        Bootloader.Start(param)
    end
}) :: {
    NewInterface:(vide:any) -> (Interface.ClassType)
} & (folder:Folder?) -> ()