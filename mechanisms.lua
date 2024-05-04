local config = require("config")

------------------------------------------------------------------------------------------mechanisms

--gets size of mechanisms array
function getMechanismSize()
    return #config.mechanisms
end

--gets certain mechanism name
function getMechanismName(index)
    return config.mechanisms[tonumber(index)].name
end

--gets all names of mechanisms
function getAllMechanismNames()
    local size = getMechanismSize() --size of mechanisms array
    names = {} --array of names

    for i = 1, size do names[i] = config.mechanisms[i].name end

    return names
end

---------------------------------------------------------------------------------------------recipes

--gets recipes array size of certain mechanism
function getRecipesSize(mechanism)
    return #config.mechanisms[tonumber(mechanism)].recipes
end

--gets recipes array size of all mechanisms
function getAllRecipesSize()
    local size = 0

    for i = 1, getMechanismSize() do
        size = size + getRecipesSize(i)
    end

    return size
end

--gets info of certain recipe
function getRecipe(mechanism, recipe)
    local info = config.mechanisms[tonumber(mechanism)].recipes[tonumber(recipe)]
    return {name = info.name, amount = info.amount}
end

--gets info of one mechanism
function getRecipes(mechanism)
    local info = {}

    for i = 1, getRecipesSize(mechanism) do
        info[i] = getRecipe(mechanism, i)
    end

    return info
end

--gets info of all recipes
function getAllRecipes()
    local info = {}

    for i = 1, getMechanismSize() do
        for j = 1, getRecipesSize(i) do
            table.insert(info, getRecipe(i, j))
        end
    end

    return info
end

-------------------------------------------------------------------------------------------materials

--gets size of materials of certain recipe
function getMaterialSize(mechanism, recipe)
    return #config.mechanisms[tonumber(mechanism)].recipes[tonumber(recipe)].materials
end

--get info about material in certain recipe e.g. name, amount
function getMaterial(mechanism, recipe, material)
    local item = config.mechanisms[tonumber(mechanism)].recipes[tonumber(recipe)].materials[tonumber(material)]
    return {name = item.material, amount = item.amount, block = item.block}
end

--get array of all needed materials in certain recipe e.g. list[1].name, list[1].amount
function getMaterials(mechanism, recipe)
    local arr = {}
    for i = 1, getMaterialSize(mechanism, recipe) do
        local material = getMaterial(mechanism, recipe, i)
        if arr[material.name] == nil then
            arr[material.name] = material
        else
            arr[material.name].amount = arr[material.name].amount + material.amount
        end
    end

    local materials = {}
    for name, material in pairs(arr) do
        table.insert(materials, material)
    end

    return materials
end

---------------------------------------------------------------------------------------------storage

--gets item information out of storage from name
function getItem(itemName)
    local storage = peripheral.wrap(config.storage)
    local amountInSlot = {}
    local slotIndex = {}

    for slot_index, item in pairs(storage.list()) do
        if item.name == itemName then
            table.insert(amountInSlot, item.count)
            table.insert(slotIndex, slot_index)
        end
    end

    if #amountInSlot == 0 or #slotIndex == 0 then return nil
    else return {name = tostring(itemName), amount = amountInSlot, slot = slotIndex} end
end

--check if we have enough resources to create item, if not, returns table of needed resources
function haveEnoughResources(mechanism, recipe, multiplier)
    local materials = getMaterials(mechanism, recipe)
    local needed = {}

    --chechking wether we still need resources for craft
    for i = 1, #materials do
        local item = getItem(materials[i].name)

        if item ~= nil then
            --difining total amount of item in the storage
            local totalAmount = 0
            for j = 1, #item.amount do
                totalAmount = totalAmount + item.amount[j]
            end

            if totalAmount < materials[i].amount*multiplier then
                table.insert(needed, {name = materials[i].name, amount = materials[i].amount*multiplier - totalAmount})
            end
        else
            table.insert(needed, {name = materials[i].name, amount = materials[i].amount*multiplier})
        end
    end

    if #needed ~= 0 then return {enough = false, needed} end

    return {enough = true, nil}
end

--creates item by deploying necessary materials in certain inventories 
function createItem(mechanism, recipe, multiplier)
    local storage = peripheral.wrap(config.storage)
    local materials = getMaterials(mechanism, recipe)

    for index, material in pairs(materials) do
        local item = getItem(material.name)

        if item == nil then
            print("There was not enough resources!")
            print("Needed %d x %s"):format(material.amount*multiplier, material.name)
            error()
        else

            --constantly create item, but in cost of preventing main thread from execution until job is done
            local block = peripheral.wrap(material.block)
            local amounts = item.amount
            local slots = item.slot
            local created = 0
            local taken = 0
            local done = false
            while not done do
                --constantly get result item
                for slot, searchable_item in pairs(block.list()) do
                    if searchable_item.name == getRecipe(mechanism, recipe).name then
                        if block.pushItems(peripheral.getName(storage), slot, 1) ~= 0 then
                            taken = taken + 1
                        end
                    end
                end

                --constantly push item
                if created == material.amount * multiplier and created == taken then
                    done = true --done pushing, all items were pushed
                elseif amounts[1] == 0 then
                    local lastSlot = table.remove(slots, 1)
                    table.remove(amounts, 1)
                    if slots[1] == nil or #slots == 0 then
                        slots[1] = lastSlot
                    end
                elseif storage.pushItems(material.block, slots[1], 1) ~= 0 then
                    amounts[1] = amounts[1] - 1
                    created = created + 1
                end
            end
        end
    end
end