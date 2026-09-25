--!strict
export type ClassType = {
    new:(vide:any?) -> (ClassType),
    Create:(ClassType, callback:() -> (GuiBase2d)) -> (ClassType),
    GetCopy:(ClassType) -> (GuiBase2d?),

    BuildFunction:(()->(GuiBase2d))?,
    Instance:GuiBase2d?,
    HasVide:boolean,
    Vide:any?,
    __index:ClassType
}

local Interface = {} :: ClassType
Interface.__index = Interface

function Interface.new(vide)
    local NewInterface = {}
    setmetatable(NewInterface, Interface)

    Interface.HasVide = vide ~= nil
    Interface.Vide = vide
    Interface.Instance = nil
    Interface.BuildFunction = nil

    return NewInterface :: ClassType
end

function Interface:Create(callback)
    local Interface:GuiBase2d?
    if self.Instance then
        self.Instance:Destroy()
    end

    if self.HasVide then
        self.Vide.root(function()
            Interface = callback()

            if typeof(Interface) == "Instance" and Interface:IsA("GuiBase2d") then
                print("is gui based")
                self.Instance = Interface
                self.BuildFunction = callback
            end
        end)
    end

    return self
end

function Interface:GetCopy()
    if self.BuildFunction then
        return self.BuildFunction()
    end

    return nil
end

return Interface