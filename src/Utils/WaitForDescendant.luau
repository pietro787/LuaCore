return function (parent: Instance,name: string, timeout: number?): Instance?
    local descendant = parent:FindFirstChild(name, true)
    if descendant then return descendant end

    local startTime = os.clock()

    while true do
        local remaining = timeout and timeout - (os.clock() - startTime)
        if remaining and remaining <= 0 then return nil end

        local instance = parent.DescendantAdded:Wait()
        if instance.Name == name then
            return instance
        end

        descendant = parent:FindFirstChild(name, true)
        if descendant then return descendant end
    end
end