type Condition<T...> = any | (T...) -> (any?)
type Result = {
    OnTimeout:(Result, callback:() -> ()) -> ()
}

local Output = require("../Output")


return function<T...>(callback:(condition:Condition<T...>) -> (), condition:Condition<T...>, timeout:number?, interval:number?, ...:T...):Result
    local function Check(...)
        if typeof(condition) == "function" then
            return condition(...)
        end

        return condition
    end

    local _callback
    local pack = table.pack(...)
    local result = {
        OnTimeout = function(self, callback)
            _callback = callback
        end
    }

    task.spawn(function()
        local waited = 0
        interval = interval or 1

        while not Check(table.unpack(pack)) do
            task.wait(interval)
            waited += interval

            if waited >= math.max(timeout or 100,  1) then
                if not _callback then break end
                local sucess, err = pcall(_callback, Check(table.unpack(pack)))

                if not sucess then
                    Output.Warn("(WaitFor) callback error. "..err)
                end 

                break
            end
        end

        if Check(table.unpack(pack)) then
            local sucess, err = pcall(callback, Check(table.unpack(pack)))

            if not sucess then
                Output.Warn("(WaitFor) callback error. "..err)
            end
        end
    end)
    
    return result
end
