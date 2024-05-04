function config()
    local config = io.open("config.json")
    local content = config:read "*a"
    return textutils.unserialiseJSON(content)
end

local content = config()

return content