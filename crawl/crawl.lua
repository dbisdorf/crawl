-- TO DO
-- precalculations at depth 0 seem slow

local crawl = {}

crawl.steps = {{0,-1},{1,0},{0,1},{-1,0}}

-- internal scaling functions

local function round(float)
	return math.floor(float + 0.5)
end

local function scaleWallImage(image, width, leftHeight, rightHeight)
	local tw, th = image:getDimensions()
	local height = math.max(leftHeight, rightHeight)
	local x1Max = width - 1
	local scaleImage = love.image.newImageData(width, height)
	local x2
	local y2
	local scaledHeight
	local scaledTop
	local scaledBottom
	local r
	local g
	local b
	local a
	local dim

	for x1 = 0, x1Max do
		if leftHeight ~= rightHeight then
			x2 = math.floor(math.log(x1 / x1Max * 3.0 + 1.0, 4) * (tw - 1))
		else
			x2 = math.floor((tw - 1) / x1Max * x1)
		end
		scaledHeight = round((rightHeight - leftHeight) / x1Max * x1 + leftHeight)
		scaledTop = round((height - scaledHeight) / 2)
		scaledBottom = scaledTop + scaledHeight - 1

		if x1 == 0 then
			-- print(string.format("scaledHeight %d scaledTop %d scaledBottom %d", scaledHeight, scaledTop, scaledBottom))
		end

		dim = ((scaledBottom - scaledTop) / crawl.wallHeight) * crawl.dimming + (1.0 - crawl.dimming)

		for y1 = scaledTop, scaledBottom do
			y2 = math.floor((th / scaledHeight) * (y1 - scaledTop))
			-- print(string.format("x2 %d y2 %d", x2, y2))
			r, g, b, a = image:getPixel(x2, y2)
			scaleImage:setPixel(x1, y1, r * dim, g * dim, b * dim, a)
		end
	end

	return love.graphics.newImage(scaleImage)
end

local function scaleHorizImage(image, height, topWidth, bottomWidth, slant)
	local tw, th = image:getDimensions()
	local topLeft = 0
	local topRight = topWidth - 1
	local bottomLeft = slant
	local bottomRight = bottomWidth + slant - 1
	local width = math.max(topRight, bottomRight) - math.min(topLeft, bottomLeft) + 1
	local y1Max = height - 1
	local scaleImage = love.image.newImageData(width, height)
	local scaledWidth
	local scaledLeft
	local scaledRight
	local x2
	local y2
	local r
	local g
	local b
	local a
	local dim

	for y1 = 0, y1Max do
		if topWidth < bottomWidth then
			y2 = math.floor(math.log(y1 / y1Max * 3.0 + 1.0, 4) * (th - 1))
		else
			y2 = math.floor(math.log((y1Max - y1) / y1Max * 3.0 + 1.0, 4) * (th - 1))
		end
		-- print(string.format("topWidth %d bottomWidth %d y1Max %d y2 %d", topWidth, bottomWidth, y1Max, y2))
		scaledWidth = math.ceil((bottomWidth - topWidth) / y1Max * y1 + topWidth)
		if bottomLeft >= 0 then
			scaledLeft = math.floor(slant / y1Max * y1)
			-- print(string.format("slant %d height %d y1 %d scaledLeft %d", slant, height, y1, scaledLeft))
		else
			scaledLeft = math.floor(-bottomLeft + slant * (y1 / y1Max))
		end
		scaledRight = scaledLeft + scaledWidth - 1
		dim = ((scaledRight - scaledLeft) / crawl.wallWidth * crawl.dimming) + (1.0 - crawl.dimming)

		if bottomWidth == 600 and y1 == 0 then
			-- print(string.format("bottomLeft %d bottomWidth %d width %d height %d scaledLeft %d scaledRight %d", bottomLeft, bottomWidth, width, height, scaledLeft, scaledRight))
			-- print(string.format("tw %d scaledWidth %d tw over scaledWidth %f", tw, scaledWidth, tw / scaledWidth))
		end

		for x1 = scaledLeft, scaledRight do
			x2 = math.floor((tw / scaledWidth) * (x1 - scaledLeft))
			-- print(string.format("x2 %d y2 %d", x2, y2))
			r, g, b, a = image:getPixel(x2, y2)
			-- print(string.format("scaledLeft %d bottomLeft %d slant %d x1 %d y1 %d ZZZ %f", scaledLeft, bottomLeft, slant, x1, y1, -bottomLeft + slant / y1Max * y1))
			scaleImage:setPixel(x1, y1, r * dim, g * dim, b * dim, a)
		end
	end

	return love.graphics.newImage(scaleImage)
end

-- utility functions

function crawl.leftFaceFrom(face)
	return (face - 2) % 4 + 1
end

function crawl.rightFaceFrom(face)
	return face % 4 + 1
end

-- main user functions

function crawl.init(wallImages, ceilingImages, floorImages, contentsImages, wallWidth, wallHeight, maxDepth, setBack, dimming, surfaceIndexFunction, contentsIndexFunction)
	local tempWalls = {}
	for i, t in ipairs(wallImages) do
		tempWalls[i] = love.image.newImageData(t)
	end
	local tempCeilings = {}
	for i, t in ipairs(ceilingImages) do
		tempCeilings[i] = love.image.newImageData(t)
	end
	local tempFloors = {}
	for i, t in ipairs(floorImages) do
		tempFloors[i] = love.image.newImageData(t)
	end
	crawl.contentsImages = {}
	for i, t in ipairs(contentsImages) do
		crawl.contentsImages[i] = love.graphics.newImage(t)
	end
	crawl.skyImage = nil

	crawl.surfaceIndexFunction = surfaceIndexFunction
	crawl.contentsIndexFunction = contentsIndexFunction
	crawl.wallWidth = wallWidth
	crawl.wallHeight = wallHeight
	crawl.maxDepth = maxDepth
	crawl.setBack = setBack
	crawl.dimming = dimming
	crawl.wallData = {}
	for depth = 0, maxDepth do
		crawl.wallData[depth] = {}
		for breadth = 0, maxDepth do
			local newWallData = {}
			local forwardScale
			if depth == 0 then
				-- I haven't decided how to calculate this value; this hardcoded value seems to be good enough for now.
				forwardScale = 4
			else
				forwardScale = setBack / (setBack + depth - 1)
			end
			local foreWidth = round(wallWidth * forwardScale)
			local foreHeight = round(wallHeight * forwardScale)
			local backScale = setBack / (setBack + depth)
			local backWidth = round(wallWidth * backScale)
			local backHeight = round(wallHeight * backScale)
			-- print(string.format("depth %d breadth %d foreWidth %d foreHeight %d backWidth %d backHeight %d", depth, breadth, foreWidth, foreHeight, backWidth, backHeight))

			if breadth == 0 then
				-- back walls
				local leftHeight = backHeight
				local rightHeight = backHeight
				newWallData.back = {
					x = round(backWidth * -0.5),
					y = round(backHeight * -0.5),
					images = {}
				}
				-- print(string.format("back wall x %d y %d", newWallData.back.x, newWallData.back.y))
				for i, t in ipairs(tempWalls) do
					newWallData.back.images[i] = scaleWallImage(t, backWidth, leftHeight, rightHeight)
				end

				-- center ceilings and floors
				local horizHeight = round((foreHeight - backHeight) / 2)
				newWallData.up = {
					x = round(foreWidth * -0.5),
					y = round(foreHeight * -0.5),
					images = {}
				}
				-- print(string.format("ceiling x %d y %d", newWallData.up.x, newWallData.up.y))
				for i, t in ipairs(tempCeilings) do
					newWallData.up.images[i] = scaleHorizImage(t, horizHeight, foreWidth, backWidth, (foreWidth - backWidth) / 2)
				end
				newWallData.down = {
					x = round(foreWidth * -0.5),
					y = round(foreHeight * 0.5) - horizHeight,
					images = {}
				}
				-- print(string.format("depth %d breadth %d floor x %d y %d backWidth %d", depth, breadth, newWallData.down.x, newWallData.down.y, backWidth))
				for i, t in ipairs(tempFloors) do
					newWallData.down.images[i] = scaleHorizImage(t, horizHeight, backWidth, foreWidth, (backWidth - foreWidth) / 2)
				end

			elseif breadth == 1 or depth > 0 then
				-- side walls
				local leftHeight = backHeight + 2
				local rightHeight = foreHeight
				local floorHeight = round((foreHeight - backHeight) / 2)
				local wallWidth = round((foreWidth - backWidth) * ((breadth - 1) * 2 + 1) / 2)
				newWallData.side = {
					x = math.floor(backWidth * -0.5 + backWidth * breadth),
					y = round(foreHeight * -0.5),
					images = {}
				}
				-- print(string.format("side wall x %d y %d wallWidth %d", newWallData.side.x, newWallData.side.y, wallWidth))
				for i, t in ipairs(tempWalls) do
					newWallData.side.images[i] = scaleWallImage(t, wallWidth, leftHeight, rightHeight)
				end

				-- side ceilings and floors
				local foreCorner = round(foreWidth * -0.5 + foreWidth * breadth)
				local backCorner = math.floor(backWidth * -0.5 + backWidth * breadth)
				newWallData.up = {
					x = backCorner,
					y = round(foreHeight * -0.5),
					images = {}
				}
				-- print(string.format("side ceiling x %d y %d", newWallData.up.x, newWallData.up.y))
				for i, t in ipairs(tempCeilings) do
					newWallData.up.images[i] = scaleHorizImage(t, floorHeight, foreWidth, backWidth, backCorner - foreCorner)
				end
				newWallData.down = {
					x = backCorner,
					y = round(foreHeight * 0.5) - floorHeight,
					images = {}
				}
				-- print(string.format("depth %d breadth %d side floor x %d y %d backWidth %d", depth, breadth, newWallData.down.x, newWallData.down.y, backWidth))
				for i, t in ipairs(tempFloors) do
					newWallData.down.images[i] = scaleHorizImage(t, floorHeight, backWidth, foreWidth, foreCorner - backCorner)
				end
			end

			crawl.wallData[depth][breadth] = newWallData
		end
	end

end

function crawl.setSkyImage(image)
	if image == nil then
		crawl.skyImage = nil
	else
		crawl.skyImage = love.graphics.newImage(image)
		local skyW, skyH = crawl.skyImage:getDimensions()
		local skyFaceW = round(skyW / 4)
		crawl.skyQuads = {}
		for i = 1, 4 do
			crawl.skyQuads[i] = love.graphics.newQuad((i - 1) * skyFaceW, 0, skyFaceW, skyH, crawl.skyImage)
		end
	end
end

function crawl.draw(canvas, x, y, facing) 
	local filterMin, filterMag, filterAni = love.graphics.getDefaultFilter()
	local originalCanvas = love.graphics.getCanvas()
	local cw, ch = canvas:getDimensions()
	local faceLeft = crawl.leftFaceFrom(facing)
	local faceRight = crawl.rightFaceFrom(facing)
	local faceBack = crawl.rightFaceFrom(faceRight)
	local stepForward = crawl.steps[facing]
	local stepLeft = crawl.steps[faceLeft]
	local stepRight = crawl.steps[faceRight]
	local wall
	local wx
	local wy
	local wallData
	local flip
	local drawBreadth

	love.graphics.setDefaultFilter("nearest")
	love.graphics.setCanvas(canvas)
	love.graphics.clear()
	love.graphics.push()
	love.graphics.translate(cw / 2, ch / 2)

	-- draw sky
	if crawl.skyImage ~= nil then
		local skyX, skyY, skyW, skyH = crawl.skyQuads[facing]:getViewport()
		local skyScale = ch / skyH
		love.graphics.draw(crawl.skyImage, crawl.skyQuads[facing], 0, 0, 0, skyScale, skyScale, round(skyW / 2), round(skyH / 2))
	end
	
	for depth = crawl.maxDepth, 0, -1 do
		if depth == 0 then
			drawBreadth = 1
		else
			drawBreadth = crawl.maxDepth
		end

		-- draw back walls
		for breadth = -drawBreadth, drawBreadth do
			wx = x + crawl.steps[facing][1] * depth + crawl.steps[faceRight][1] * breadth
			wy = y + crawl.steps[facing][2] * depth + crawl.steps[faceRight][2] * breadth
			wall = crawl.surfaceIndexFunction(wx, wy, facing)
			if wall > 0 then
				wallData = crawl.wallData[depth][0].back
				local ww, wh = wallData.images[wall]:getDimensions()
				love.graphics.draw(wallData.images[wall], wallData.x + ww * breadth, wallData.y)
			end
		end

		-- draw ceilings and floors
		for breadth = -drawBreadth, drawBreadth do
			if breadth < 0 then
				flip = -1
			else
				flip = 1
			end
			wx = x + crawl.steps[facing][1] * depth + crawl.steps[faceRight][1] * breadth
			wy = y + crawl.steps[facing][2] * depth + crawl.steps[faceRight][2] * breadth
			wall = crawl.surfaceIndexFunction(wx, wy, 5)
			if wall > 0 then
				wallData = crawl.wallData[depth][math.abs(breadth)].up
				love.graphics.draw(wallData.images[wall], wallData.x * flip, wallData.y, 0, flip, 1)
			end
			wall = crawl.surfaceIndexFunction(wx, wy, 6)
			if wall > 0 then
				wallData = crawl.wallData[depth][math.abs(breadth)].down
				love.graphics.draw(wallData.images[wall], wallData.x * flip, wallData.y, 0, flip, 1)
			end
		end

		-- draw contents and side walls
		wallData = crawl.wallData[depth][0].down
		local backY = wallData.y
		local floorWidth, foreHeight = wallData.images[1]:getDimensions()
		local foreY = backY + foreHeight - 1
		local backWallData = crawl.wallData[depth][0].back
		local backWidth, backHeight = backWallData.images[1]:getDimensions()
		for breadth = -drawBreadth, drawBreadth do
			-- side walls 
			if breadth < 1 and breadth > -drawBreadth then
				-- left side or center
				wx = x + crawl.steps[facing][1] * depth + crawl.steps[faceLeft][1] * -breadth
				wy = y + crawl.steps[facing][2] * depth + crawl.steps[faceLeft][2] * -breadth
				wall = crawl.surfaceIndexFunction(wx, wy, faceLeft)
				-- print(string.format("walls on left side depth %d breadth %d wx %d wy %d faceLeft %d", depth, breadth, wx, wy, faceLeft))
				if wall > 0 then
					wallData = crawl.wallData[depth][-breadth + 1].side
					love.graphics.draw(wallData.images[wall], -wallData.x, wallData.y, 0, -1, 1)
				end
			end
			if breadth > -1 and breadth < drawBreadth then
				-- right side or center
				wx = x + crawl.steps[facing][1] * depth + crawl.steps[faceRight][1] * breadth
				wy = y + crawl.steps[facing][2] * depth + crawl.steps[faceRight][2] * breadth
				wall = crawl.surfaceIndexFunction(wx, wy, faceRight)
				-- print(string.format("walls on right side depth %d breadth %d wx %d wy %d faceRight %d", depth, breadth, wx, wy, faceRight))
				if wall > 0 then
					wallData = crawl.wallData[depth][breadth + 1].side
					love.graphics.draw(wallData.images[wall], wallData.x, wallData.y)
				end
			end

			-- contents
			wx = x + crawl.steps[facing][1] * depth + crawl.steps[faceRight][1] * breadth
			wy = y + crawl.steps[facing][2] * depth + crawl.steps[faceRight][2] * breadth
			local contents = crawl.contentsIndexFunction(wx, wy)
			if contents ~= nil then
				for i, c in ipairs(contents) do
					local cy = round((foreY - backY) * c[3] + backY)
					local cw = round((floorWidth - backWidth) * c[3] + backWidth)
					local cx = (cw * -0.5) + (cw * breadth) + (cw * c[2])
					local ctw, cth = crawl.contentsImages[c[1]]:getDimensions()
					local cScale = crawl.setBack / (crawl.setBack + depth - 1 + (1.0 - c[3]))
					love.graphics.draw(crawl.contentsImages[c[1]], cx, cy, 0, cScale, cScale, round(ctw / 2), cth)
				end
			end
		end
	end

	love.graphics.setCanvas(originalCanvas)
	love.graphics.pop()
	love.graphics.setDefaultFilter(filterMin, filterMag, filterAni)
end


return crawl

