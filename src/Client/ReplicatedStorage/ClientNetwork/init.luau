local methods = {}
local Gateway = {}

for _, modules in next, script:GetChildren() do
    for methodName, method in next, require(modules) do
        methods[methodName] = method
    end
end


function Gateway.ProcessRequest(requestId : string, ...)
    if methods[requestId] then
        return methods[requestId](...)
    end

    error(methods[requestId] or "Request not found")

    return nil
end

return Gateway