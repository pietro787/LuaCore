local TagController = {}

-- :Tag(name) -> ComponenteHelper -> :Isa(), :Server(), :Client(), :Get() -> Componente
local Helpers = {}

function TagController:Tag(name:string)
    local NewComponenteHelper = {}
    Helpers[name] = NewComponenteHelper
    

    return NewComponenteHelper
end

return TagController