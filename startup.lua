local button = require("button") --button api
local config = require("config") --configurations
local utils = require("utils") --utils
require("mechanisms")
local monitor = peripheral.find("monitor") --monitor
local width, height = monitor.getSize() --monitor sizes

--setting all up
button.setMonitor(monitor)
local chooseRecipes = true --control while loop which draws buttons
local from = 1

function label(first_half, second_half)

    local line = config.dictionary.labels.separator
    for i = 1, width do
        line = line .. config.dictionary.labels.separator
    end

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    -- monitor.setCursorPos(1,1)
    -- monitor.write(line)

    monitor.setCursorPos(width/4 - string.len(first_half)/2, 2)
    monitor.write(first_half)
    monitor.setCursorPos(width*3/4 - string.len(second_half)/2, 2);
    monitor.write(second_half)
    
    monitor.setCursorPos(1, 3)
    monitor.write(line)
end

--draw menu for item amoun selection
local function createItemCraftScreen(mechanism, item)
    chooseRecipes = false --stops while loop from drawing buttons
    local recipe = getRecipe(mechanism, item)
    local itemName = utils.getClearItemName(recipe.name)

    clearMon()
    label(config.dictionary.labels.createLabel, config.dictionary.labels.statsLabel)
    local done = false

    local sum = 1;
    local sum_position = width*9/24 - 1
    local sum_height = 8

    local positives = {1, 16, 32, 64}
    local negatives = {-1, -16, -32, -64}
    local both = {}
    local buttons = {}

    --defining button names
    local createName = config.dictionary.buttons.create
    local denyName = config.dictionary.buttons.deny

    --refreshes screen once calculator buttons are pressed
    local function refresh()
        local buttonSpace = 2 --space between buttons
        local offsetX = 3

        --display how much of item will be craft
        local craft = recipe.amount*sum.." x"..string.upper(itemName)
        monitor.setCursorPos(width/2 - string.len(craft)/2, sum_height - 2)
        monitor.clearLine()
        monitor.write(craft) --writing item's name 

        --creating "Create" button
        local createButton = 
        button.create(createName)
        .setPos(width/2 - string.len(createName)/2 - buttonSpace - offsetX, sum_height + 6)
        .setSize(string.len(createName) + 2, 3)
        .setTextColor(colors.white)
        .setBlinkColor(colors.gray)
        .setAlign("center")
        .onClick(function () 
            createItem(mechanism, item, sum)
            done = true
            chooseRecipes = true
            main()
        end)
    
        if haveEnoughResources(mechanism, item, sum).enough then
            createButton.setBackgroundColor(colors.green)
            createButton.setActive(true)
        else
            createButton.setBackgroundColor(colors.gray)
            createButton.setActive(false)
        end

        --creating "Deny" button
        local denyButton =
        button.create(denyName)
        .setPos(width/2 + string.len(denyName)/2 + buttonSpace - offsetX, sum_height + 6)
        .setSize(string.len(denyName) + 2, 3)
        .setTextColor(colors.white)
        .setBackgroundColor(colors.red)
        .setBlinkColor(colors.gray)
        .setAlign("center")
        .onClick(function ()
            chooseRecipes = true
            main()
        end)

        --inserting newly created buttons to array 
        table.insert(buttons, #buttons+1, denyButton)
        table.insert(buttons, #buttons+1, createButton)
    end

    local function drawSum(sum)
        monitor.setCursorPos(sum_position, sum_height)
        monitor.setTextColor(colors.white)
        monitor.setBackgroundColor(colors.gray)

        local spaces = " "
        local remove = 0

        if(sum > 9) then remove = 1
        elseif(sum > 99) then remove = 2
        elseif(sum > 999) then remove = 3 end

        for i = 1, 3*#both/2 + 1 - remove do spaces = spaces .. " " end

        monitor.write(sum..spaces)
        monitor.setBackgroundColor(colors.black)
    end

    local function add(num)
        if sum == 1 and num > 1 then 
            sum = num
        else 
            sum = sum + num
        end

        if(sum < 1) then sum = 1 end
        drawSum(sum)
    end

    --creating array of both (positive and negative) numbers
    button.mergeTables(both, positives)
    button.mergeTables(both, negatives)

    for i = 1, #both do --creating buttons
        local num = both[i]

        buttons[num] = button
        .create(tostring(num))
        .setTextColor(colors.white)
        .setBlinkColor(colors.gray)
        .onClick(function () 
            add(num)
            table.remove(buttons)
            refresh()
        end)
    end

    for i = 1, #positives do --settings for positives buttons
        local num = positives[i]

        buttons[num]
        .setBackgroundColor(colors.green)
        .setPos(sum_position + #positives*(i - 1), sum_height + 2)
        .setSize(3, 1)
        .setAlign("right")
    end

    for i = 1, #negatives do --settings for negatives buttons
        local num = negatives[i]

        buttons[num]
        .setBackgroundColor(colors.red)
        .setPos(sum_position + #negatives*(i - 1), sum_height + 4)
        .setSize(3, 1)
        .setAlign("right")
    end

    drawSum(sum) --draw calculator
    refresh() --draw buttons after calculator
    while not done do --draw buttons
        button.await(buttons)
    end
end

--creating array out of button names 
local function createButtonList()
    local buttons = {}
    local mechanisms = getAllMechanismNames()

    for i = 1, #mechanisms do
        local recipes = getRecipes(i)
    
        for index = 1, #recipes do
            local recipe = recipes[index].name
            local craft = string.upper(utils.getClearItemName(recipe))
            table.insert(buttons, button
                .create(craft)
                .setSize(string.len(recipe) + 2, 1)
                .setAlign("center")
                .setTextColor(colors.white)
                .setBackgroundColor(colors.black)
                .setBlinkColor(colors.gray)
                .onClick(function () createItemCraftScreen(i, index) end)
        )
        end
    end

    local available_height = height - 5
    buttons = utils.substring(buttons, from, available_height)

    for i = 1, #buttons do
        buttons[i].setPos(width/6 - string.len(buttons[1].getText())/2, 4 + i)
    end

    table.insert(buttons, button
        .create("/\\")
        .setPos(width/6 - 1, 4)
        .setSize(width/4 - 1, 1)
        .setAlign("center")
        .setTextColor(colors.white)
        .setBackgroundColor(colors.black)
        .setBlinkColor(colors.gray)
        .onClick(function ()
            from = from - 1
            if from < 1 then from = 1 end
            main()
        end))

    table.insert(buttons, button
        .create("\\/")
        .setPos(width/6 - 1, height - 1)
        .setSize(width/4 - 1, 1)
        .setAlign("center")
        .setTextColor(colors.white)
        .setBackgroundColor(colors.black)
        .setBlinkColor(colors.gray)
        .onClick(function ()
            from = from + 1
            if from > #buttons then from = #buttons + 1 end
            main()
        end))

    return buttons
end

function main()
    clearMon()
    --label creation
    label(config.dictionary.labels.createLabel, "")

    --done!
    monitor.setCursorPos(1, 1)
    local buttons = createButtonList()
    while chooseRecipes do button.await(buttons) end
end

return main()
