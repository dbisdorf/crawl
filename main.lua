-- TODO
-- hero heads

crawl = require "crawl/crawl"

-- constants

BUTTONS_X = 1060
BUTTONS_Y = 444

WALLS = {
	{index = 1, squares = {{3,1}, {4,1}}},
	{index = 1, squares = {{2,1}, {2,2}}},
	{index = 2, squares = {{3,1}, {3,2}}},
	{index = 1, squares = {{1,2}, {2,2}}},
	{index = 1, squares = {{3,2}, {4,2}}},
	{index = 2, squares = {{4,2}, {4,3}}},
	{index = 1, squares = {{5,2}, {5,3}}},
	{index = 1, squares = {{1,3}, {2,3}}},
	{index = 2, squares = {{3,3}, {4,3}}},
	{index = 1, squares = {{4,3}, {5,3}}},
	{index = 1, squares = {{2,3}, {2,4}}},
	{index = 1, squares = {{3,3}, {3,4}}},
	{index = 2, squares = {{5,3}, {5,4}}},
	{index = 2, squares = {{1,4}, {2,4}}},
	{index = 1, squares = {{1,4}, {1,5}}},
	{index = 1, squares = {{2,4}, {3,4}}},
	{index = 1, squares = {{4,4}, {5,4}}},
	{index = 1, squares = {{3,4}, {3,5}}},
	{index = 1, squares = {{4,4}, {4,5}}},
	{index = 2, squares = {{3,5}, {4,5}}}
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

DUNGEON_VIEW_SIZE = {1024, 768}
DUNGEON_VIEW_ORIGIN = {16, 17}
WINDOW_SIZE = {1280, 800}
HERO_STATS_LEFT = 1152
HERO_STATS_SPACING = 128
INV_OFFSET = 6

WALL_IMAGES = {
	"assets/wall.png", 
	"assets/door.png", 
	"assets/opendoor.png",
	"assets/outerwall.png"
}
FLOOR_IMAGES = {
	"assets/floor.png"
}
CONTENTS_IMAGES = {
	"assets/skeleton.png", 
	"assets/potion.png", 
	"assets/scroll.png"
}
SKY_IMAGE = "assets/sky.png"
FRAME_IMAGE = "assets/frame.png"

NEAR_WALL_SIZE = 600
DRAW_DEPTH = 4
DRAW_SETBACK = 0.8
DIMMING = 0.5

-- global variables

contents = {
	{square = {1,4}, contents = {{1, 0.5, 0.5}}},
	{square = {2,3}, contents = {{2, 0.4, 0.02},{3, 0.6, 0.02}}}
}

heroStats = {
	{name = "Alpha", hits = 17},
	{name = "Beta", hits = 3},
	{name = "Gamma", hits = 11}
}

inventory = {}

-- game startup

function love.load()

	frameImage = love.graphics.newImage(FRAME_IMAGE)
	lootImages = {
		love.graphics.newImage(CONTENTS_IMAGES[2]),
		love.graphics.newImage(CONTENTS_IMAGES[3])
	}

	canvas = love.graphics.newCanvas(DUNGEON_VIEW_SIZE[1], DUNGEON_VIEW_SIZE[2])
	redraw = true
	playerX = 4
	playerY = 1
	playerFace = 3
	hoveredButton = 0
	crawlSetup = false
	waitMessage = false
end

-- input callback functions

function love.keypressed(key, scancode, isrepeat)
	downButton = true
	hoveredButton = buttonForKey(key)
end

function love.keyreleased(key, scancode)
	downButton = false
	local button = buttonForKey(key)
	if button > 0 then
		hoveredButton = button
		executeControl(BUTTONS[button].control)
	end
	hoveredButton = 0
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

-- main game data update function

function love.update(dt)
	if waitMessage and not crawlSetup then
		setupCrawl()
		crawlSetup = true
	end
end

-- main drawing function

function love.draw()
	-- if the library isn't set up, show a waiting message
	if not crawlSetup then
		waitMessage = true
		love.graphics.printf("Please wait...", 0, WINDOW_SIZE[2] / 2, WINDOW_SIZE[1], "center")
		return
	end

	-- redraw the dungeon view canvas if needed
	if redraw then
		crawl.draw(canvas, playerX, playerY, playerFace)
		redraw = false
	end

	-- draw the UI frame and the dungeon view canvas
	love.graphics.draw(frameImage)
	love.graphics.draw(canvas, DUNGEON_VIEW_ORIGIN[1], DUNGEON_VIEW_ORIGIN[2])

	-- draw hero stats
	for i, hero in ipairs(heroStats) do
		love.graphics.print(hero.name, HERO_STATS_LEFT, math.floor(HERO_STATS_SPACING * (i - 0.5)))
		love.graphics.print(string.format("Hits: %d", hero.hits), HERO_STATS_LEFT, math.floor(HERO_STATS_SPACING * (i - 0.2)))
	end

	-- draw inventory
	for i, loot in ipairs(inventory) do
		if loot > 0 then
			love.graphics.draw(lootImages[loot - 1], BUTTONS[i].x + INV_OFFSET, BUTTONS[i].y + INV_OFFSET)
		end
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

-- crawl library initializtion and callbacks

function setupCrawl()
	-- initialize the crawl library
	crawl.init(WALL_IMAGES, FLOOR_IMAGES, FLOOR_IMAGES, CONTENTS_IMAGES, 
		NEAR_WALL_SIZE, NEAR_WALL_SIZE, DRAW_DEPTH, DRAW_SETBACK, DIMMING, 
		surfaceIndexFunction, contentsIndexFunction)
	crawl.setSkyImage(SKY_IMAGE)
end

function surfaceIndexFunction(surface, x, y, face)
	local x2 = x 
	local y2 = y 
	if face > 0 then
		x2 = x + crawl.steps[face][1]
		y2 = y + crawl.steps[face][2]
	end
	local oob1 = outOfBounds(x, y)
	local oob2 = outOfBounds(x2, y2)
	if oob1 and oob2 then
		-- completely out of bounds
		return 0
	elseif surface == "wall" then
		-- walls
		if oob1 or oob2 then
			-- boundary walls
			if x > 3 and y < 3 then
				return 4
			end
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
		if x < 4 or y > 2 then
			return 1
		end
		return 0
	end
end

function contentsIndexFunction(x, y)
	for i, c in ipairs(contents) do
		if x == c.square[1] and y == c.square[2] then
			return c.contents
		end
	end
	return nil
end

-- maze logic

function outOfBounds(x, y)
	return (x < 1 or x > 5 or y < 1 or y > 5)
end

function wallBetween(x1, y1, x2, y2)
	for i, w in ipairs(WALLS) do
		if (w.squares[1][1] == x1 and w.squares[1][2] == y1 and w.squares[2][1] == x2 and w.squares[2][2] == y2) or 
			(w.squares[1][1] == x2 and w.squares[1][2] == y2 and w.squares[2][1] == x1 and w.squares[2][2] == y1) then
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
	local x2 = x + crawl.steps[facing][1]
	local y2 = y + crawl.steps[facing][2]
	for i, w in ipairs(WALLS) do
		if (w.squares[1][1] == x and w.squares[1][2] == y and w.squares[2][1] == x2 and w.squares[2][2] == y2) or 
			(w.squares[1][1] == x2 and w.squares[1][2] == y2 and w.squares[2][1] == x and w.squares[2][2] == y) then
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
	for i, c in ipairs(contents) do
		if c.square[1] == x and c.square[2] == y and #c.contents > 0 then
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
	for i, c in ipairs(contents) do
		if c.square[1] == x and c.square[2] == y and #c.contents > 0 then
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
	elseif control == "inv" then
		inventory[hoveredButton] = 0
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

