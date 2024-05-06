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

--gets block name by mechanism's index
function getMechanismOutputBlock(mechanism)
    return tostring(config.mechanisms[tonumber(mechanism)].block)
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

--gets material's info from name
function getMaterialInfoByName(name)

    for j = 1, getMechanismSize() do
        local recipes = getRecipes(j)
        for k = 1, #recipes do
            if recipes[k].name == name then
                return {found = true, mechanism = j, recipe = k}
            end
        end
    end
    return {found = false, mechanism = nil, recipe = nil}
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
        else --check if the needed material have a recipe
            local item_info = getMaterialInfoByName(materials[i].name)
            if item_info.found then --only work if item can be crafted
                local multiplier_x = materials[i].amount*multiplier / recipes[i].amount --how much we need of that item
                local recursive = haveEnoughResources(j, k, multiplier_x)

                if recursive.enough == false then
                    table.insert(needed, recursive.need)
                end
            else --we don't have enough items, fill up needed array
                table.insert(needed, {name = materials[i].name, amount = materials[i].amount*multiplier})
            end
        end
    end

    if #needed ~= 0 then return {enough = false, need = needed} end

    return {enough = true, nil}
end

--creates item by deploying necessary materials in certain inventories 
function createItem(mechanism, recipe, multiplier)
    local storage = peripheral.wrap(config.storage)
    local materials = getMaterials(mechanism, recipe)

    for index, material in pairs(materials) do
        local item = getItem(material.name) --gets item from storage

        if item == nil then --item was not found in storage, will try to craft it if possible
            local material_info = getMaterialInfoByName(material.name)
            if material_info.found == false then
                print("There was not enough resources!")
                print("Needed %d x %s"):format(material.amount*multiplier, material.name)
                error()
                return
            end

            local material_recipe = getRecipe(material_info.mechanism, material_info.recipe) --recipe of the material that we can craft
            local multiplier_material = material.amount*multiplier / material_recipe.amount --how much we need of that item
            createItem(material_info.mechanism, material_info.recipe, multiplier_material) --craft!
        else --constantly create item, but in cost of preventing main thread from execution until job is done
            local input_block = material.block
            local output_block = peripheral.wrap(getMechanismOutputBlock(mechanism))
            local recipe_info = getRecipe(mechanism, recipe)
            local amounts = item.amount
            local slots = item.slot
            local created = 0
            local taken = 0
            local done = false
            while not done do
                --constantly pull result item to storage
                for slot, searchable_item in pairs(output_block.list()) do
                    if searchable_item.name == recipe_info.name then
                        local taken_amount = output_block.pushItems(config.storage, slot, recipe_info.amount)
                        --tracking how much did we take result items
                        if taken_amount ~= 0 then taken = taken + taken_amount end
                    end
                end

                --constantly push item to mechanism's input block
                if created == recipe_info.amount * multiplier and created == taken then
                    done = true --done pushing, all items were pushed
                elseif amounts[1] == 0 then --remove used slot from the list of slots
                    local lastSlot = table.remove(slots, 1)
                    table.remove(amounts, 1)

                    --saving last slot in case it is deleted
                    if slots[1] == nil or #slots == 0 then 
                        slots[1] = lastSlot
                    end
                --pushing certain amount of resources which we created
                elseif storage.pushItems(input_block, slots[1], material.amount) ~= 0 then 
                    print(amounts[1])
                    --tracking amount of materials which were used to craft item(s)
                    amounts[1] = amounts[1] - material.amount
                    --tracking amount of resources we created from recipe
                    created = created + recipe_info.amount
                end
            end
        end
    end
end