--!strict
return (function()
    local endpoints = {}
    for i, modules in next, script:GetChildren() do
        if modules:IsA("ModuleScript") then
            endpoints[modules.Name] = (function()
                local modData = {}
                for name, method in next, require(modules) do
                    modData[name] = method
                end
                return modData
            end)
        end
    end

    return endpoints
end)()