function split (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

function getClearItemName(itemName)
    local splittedName = split(split(tostring(itemName), ":")[2], "_")
    local name = ""
    for i = 1, #splittedName do
        name = name.." "..splittedName[i]
    end
    return name
end

function substring(list, pos1, pos2)
    local final = {}

    if pos1 > pos2 then
        local temp = pos1
        pos1 = pos2
        pos2 = temp
    end
    if pos1 > #list then pos1 = #list - pos1 end
    if pos1 < 1 then pos1 = 1 end
    if pos2 > #list then pos2 = #list end

    for i = pos1, pos2 do table.insert(final, list[i]) end
    return final
end

return {split = split, getClearItemName = getClearItemName, substring = substring}