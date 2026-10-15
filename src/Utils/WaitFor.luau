type Result = {
    OnTimeout:(Result, callback:() -> ()) -> ()
}

local Output = require("../Output")

return function<T>(callback:(condition:T) -> (), condition:T, timeout:number?, interval:number?):Result
    local _callback
    local result = {
        OnTimeout = function(self, callback)
            task.spawn(function()
                _callback = callback
            end)
        end
    }

    task.spawn(function()
        local waited = 0

        while not condition do
            task.wait(interval)
            waited += interval

            if waited >= math.max(timeout or 100,  1) then
                local sucess, err = pcall(callback, condition)

                if not sucess then
                    Output.Warn("(WaitFor) callback error. "..err)
                end
            end
        end

        if condition then
            local sucess, err = pcall(callback, condition)

            if not sucess then
                Output.Warn("(WaitFor) callback error. "..err)
            end
        end
    end)
    
    return result
end
