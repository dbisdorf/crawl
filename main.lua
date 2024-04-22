-- TODO
-- "cell" or "square"?
-- change square number math to xy coords
-- attack
-- use item
-- verbage: images/textures?

crawl = require "crawl/crawl"

-- constants

BUTTONS_X = 1060
BUTTONS_Y = 444

WALLS = {
	{index = 1, cells = {3, 4}},
	{index = 1, cells = {2, 7}},
	{index = 2, cells = {3, 8}},
	{index = 1, cells = {6, 7}},
	{index = 1, cells = {8, 9}},
	{index = 2, cells = {9, 14}},
	{index = 1, cells = {10, 15}},
	{index = 1, cells = {11, 12}},
	{index = 2, cells = {13, 14}},
	{index = 1, cells = {14, 15}},
	{index = 1, cells = {12, 17}},
	{index = 1, cells = {13, 18}},
	{index = 2, cells = {15, 20}},
	{index = 2, cells = {16, 17}},
	{index = 1, cells = {16, 21}},
	{index = 1, cells = {17, 18}},
	{index = 1, cells = {19, 20}},
	{index = 1, cells = {18, 23}},
	{index = 1, cells = {19, 24}},
	{index = 2, cells = {23, 34}}
}

BUTTONS = {
	{x = 1060, y = 444, key = "1",      control = "inv"},
	{x = 1128, y = 444, key = "2",      control = "inv"},
	{x = 1196, y = 444, key = "3",      control = "inv"},
	{x = 1060, y = 512, key = "4",      control = "inv"},
	{x = 1128, y = 512, key = "5",      control = "inv"},
	{x = 1196, y = 512, key = "6",      control = "inv"},
	{x = 1060, y = 580, key = "q",      control = "turnleft"},
	{x = 1128, y = 580, key = "w",      control = "forward"},
	{x = 1196, y = 580, key = "e",      control = "turnright"},
	{x = 1060, y = 648, key = "a",      control = "stepleft"},
	{x = 1128, y = 648, key = "s",      control = "back"},
	{x = 1196, y = 648, key = "d",      control = "stepright"},
	{x = 1060, y = 716, key = "space",  control = "interact"},
	{x = 1128, y = 716, key = "return", control = "attack"},
	{x = 1196, y = 716, key = "escape", control = "exit"}
}

BUTTON_SIZE = 64

-- global variables

contents = {
	{cell = 16, contents = {{1, 0.5, 0.5}}},
	{cell = 12, contents = {{2, 0.4, 0.02},{3, 0.6, 0.02}}}
}

heroStats = {
	{name = "Alpha", hits = 17},
	{name = "Beta", hits = 3},
	{name = "Gamma", hits = 11}
}

inventory = {}

-- game startup

function love.load()
	wallTextures = {
		"assets/wall.png", 
		"assets/door.png", 
		"assets/opendoor.png"
	}
	floorTextures = {
		"assets/floor.png"
	}
	contentsTextures = {
		"assets/skeleton.png", 
		"assets/potion1.png", 
		"assets/potion2.png"
	}
	crawl.init(wallTextures, floorTextures, floorTextures, contentsTextures, 
		600, 600, 4, 0.8, 0.5, 
		surfaceIndexFunction, contentsIndexFunction)
	crawl.setSkyTexture("assets/sky.png")

	frameTexture = love.graphics.newImage("assets/frame.png")
	lootImages = {
		love.graphics.newImage("assets/potion1.png"),
		love.graphics.newImage("assets/potion2.png")
	}

	canvas = love.graphics.newCanvas(1024, 768)
	redraw = true
	playerX = 1
	playerY = 1
	playerFace = 2
	hoveredButton = 0
end

-- input callback functions

function love.keypressed(key, scancode, isrepeat)
	downButton = true
	hoveredButton = buttonForKey(key)
end

function love.keyreleased(key, scancode)
	hoveredButton = 0
	downButton = false
	local button = buttonForKey(key)
	if button > 0 then
		executeControl(BUTTONS[button].control)
	end
end

function love.mousemoved(x, y, dx, dy, istouch)
	hoveredButton = buttonAtCoords(x, y)
end

function love.mousepressed(x, y, button, istouch, presses)
	if button == 1 then
		downButton = true
	end
end

function love.mousereleased(x, y, button, istouch, presses)
	downButton = false
	if button == 1 and hoveredButton > 0 then
		executeControl(BUTTONS[hoveredButton].control)
	end
end

-- main drawing function

function love.draw()
	-- redraw the dungeon view canvas if needed
	if redraw then
		crawl.draw(canvas, playerX, playerY, playerFace)
		redraw = false
	end

	-- draw the UI frame and the dungeon view canvas
	love.graphics.draw(frameTexture)
	love.graphics.draw(canvas, 16, 16)

	-- draw hero stats
	for i, hero in ipairs(heroStats) do
		love.graphics.print(hero.name, 1152, 128 * i - 64)
		love.graphics.print(string.format("Hits: %d", hero.hits), 1152, 128 * i - 48)
	end

	-- draw inventory
	for i, loot in ipairs(inventory) do
		love.graphics.draw(lootImages[i], BUTTONS[i].x + 6, BUTTONS[i].y + 4)
	end

	-- highlight UI elements based on user input
	if hoveredButton > 0 then
		local method = "line"
		if downButton then
			love.graphics.setColor(1.0, 1.0, 1.0, 0.5)
			love.graphics.rectangle("fill", BUTTONS[hoveredButton].x, BUTTONS[hoveredButton].y, BUTTON_SIZE, BUTTON_SIZE)
			love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
		else
			love.graphics.rectangle("line", BUTTONS[hoveredButton].x, BUTTONS[hoveredButton].y, BUTTON_SIZE, BUTTON_SIZE)
		end
	end
end

-- callback functions for crawl library

function surfaceIndexFunction(surface, x, y, face)
	-- print(string.format("x %d y %d face %d", x, y, face))
	if x < 0 or x > 6 or y < 0 or y > 6 then
		-- out of bounds
		return 0
	elseif surface == "wall" then
		-- walls
		local x2 = x + crawl.steps[face][1]
		local y2 = y + crawl.steps[face][2]
		if x == 0 or x == 6 or y == 0 or y == 6 or x2 == 0 or x2 == 6 or y2 == 0 or y2 == 6 then
			-- boundary walls
			return 1
		else
			-- interior walls
			return wallBetween(x, y, x2, y2)
		end
	elseif surface == "floor" then
		-- floors
		return 1
	elseif surface == "ceiling" then
		-- ceilings
		return 1
	end
end

function contentsIndexFunction(x, y)
	for i, c in ipairs(contents) do
		if x + (y - 1) * 5 == c.cell then
			return c.contents
		end
	end
	return nil
end

-- maze logic

function wallBetween(x1, y1, x2, y2)
	local c1 = x1 + (y1 - 1) * 5
	local c2 = x2 + (y2 - 1) * 5
	for i, w in ipairs(WALLS) do
		if (w.cells[1] == c1 and w.cells[2] == c2) or (w.cells[1] == c2 and w.cells[2] == c1) then
			return w.index
		end
	end
	return 0
end

function validMove(x1, y1, x2, y2)
	if x2 < 1 or x2 > 5 or y2 < 1 or y2 > 5 then
		return false
	else
		local contents = contentsIndexFunction(x2, y2)
		if contents ~= nil then
			for i, c in ipairs(contents) do
				if c[1] == 1 then
					return false
				end
			end
		end
		local w = wallBetween(x1, y1, x2, y2)
		return w == 0 or w == 3
	end
	return true
end

function useDoor(x, y, facing)
	local c1 = x + (y - 1) * 5
	local c2 = x + crawl.steps[facing][1] + (y + crawl.steps[facing][2] - 1) * 5
	for i, w in ipairs(WALLS) do
		if (w.cells[1] == c1 and w.cells[2] == c2) or (w.cells[1] == c2 and w.cells[2] == c1) then
			if w.index == 2 then 
				w.index = 3
				return true
			elseif w.index == 3 then
				w.index = 2
				return true
			end
		end
	end
	return false
end

function grabLoot(x, y)
	local grabbed = false
	local square = x + (y - 1) * 5
	for i, c in ipairs(contents) do
		if c.cell == square and #c.contents > 0 then
			for i, loot in ipairs(c.contents) do
				table.insert(inventory, loot[1])
			end
			grabbed = true
			c.contents = {}
		end
	end
	return grabbed
end

function attackMonster(x, y)
	local attacked = false
	local square = x + (y - 1) * 5
	for i, c in ipairs(contents) do
		if c.cell == square and #c.contents > 0 then
			for i, monster in ipairs(c.contents) do
				if monster[1] == 1 then
					attacked = true
				end
			end
			if attacked then
				c.contents = {}
			end
		end
	end
	return attacked
end


-- user control functions

function buttonAtCoords(x, y)
	for i, b in ipairs(BUTTONS) do
		if x >= b.x and x < b.x + BUTTON_SIZE and y >= b.y and y < b.y + BUTTON_SIZE then
			return i
		end
	end
	return 0
end

function buttonForKey(key)
	for i, b in ipairs(BUTTONS) do
		if key == b.key then
			return i
		end
	end
	return 0
end

function executeControl(control)
	local oldX = playerX
	local oldY = playerY
	local oldFace = playerFace
	local newX = playerX
	local newY = playerY
	if control == "exit" then
		love.event.quit()
	elseif control == "interact" then
		if grabLoot(playerX, playerY) then
			redraw = true
		elseif useDoor(playerX, playerY, playerFace) then
			redraw = true
		end
	elseif control == "attack" then
		local wall = surfaceIndexFunction("wall", playerX, playerY, playerFace)
		if wall == 0 or wall == 2 then
			if attackMonster(playerX + crawl.steps[playerFace][1], playerY + crawl.steps[playerFace][2]) then
				redraw = true
			end
		end
	elseif control == "forward" then
		newX = playerX + crawl.steps[playerFace][1]
		newY = playerY + crawl.steps[playerFace][2]
	elseif control == "back" then
		newX = playerX - crawl.steps[playerFace][1]
		newY = playerY - crawl.steps[playerFace][2]
	elseif control == "stepleft" then
		newX = playerX + crawl.steps[crawl.leftFaceFrom(playerFace)][1]
		newY = playerY + crawl.steps[crawl.leftFaceFrom(playerFace)][2]
	elseif control == "stepright" then
		newX = playerX + crawl.steps[crawl.rightFaceFrom(playerFace)][1]
		newY = playerY + crawl.steps[crawl.rightFaceFrom(playerFace)][2]
	elseif control == "turnright" then
		playerFace = crawl.rightFaceFrom(playerFace)
	elseif control == "turnleft" then
		playerFace = crawl.leftFaceFrom(playerFace)
	end
	if newX ~= oldX or newY ~= oldY then
		if validMove(oldX, oldY, newX, newY) then
			playerX = newX
			playerY = newY
		end
	end
	if oldX ~= playerX or oldY ~= playerY or oldFace ~= playerFace then
		redraw = true
	end
end

