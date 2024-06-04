--!strict
return  { 
    SafeCall = function(delegate : any, ...)
        local success, result
        for i = 0, 5 do
            success, result = pcall(delegate, ...)
            if success then
                break
            end
            
            warn("Error: ", result)
            task.wait(2 ^ 5)
        end
    
        return result, success
    end
    
}