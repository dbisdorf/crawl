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

	for x1 = 0, width - 1 do
		if leftHeight ~= rightHeight then
			x2 = math.floor(math.log(x1 / width * 3.0 + 1.0, 4) * tw)
		else
			x2 = math.floor(tw / width * x1)
		end
		scaledHeight = round((rightHeight - leftHeight) / width * x1 + leftHeight)
		scaledTop = (height - scaledHeight) / 2
		scaledBottom = scaledTop + scaledHeight - 1
		dim = ((scaledBottom - scaledTop) / crawl.wallHeight) * crawl.dimming + (1.0 - crawl.dimming)

		for y1 = scaledTop, scaledBottom do
			y2 = math.floor((th / scaledHeight) * (y1 - scaledTop))
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

	for y1 = 0, height - 1 do
		if topWidth < bottomWidth then
			y2 = math.floor(math.log(y1 / height * 3.0 + 1.0, 4) * th)
		else
			y2 = math.floor(math.log((height - 1 - y1) / height * 3.0 + 1.0, 4) * th)
		end
		scaledWidth = round((bottomWidth - topWidth) / height * y1 + topWidth)
		if bottomLeft >= 0 then
			scaledLeft = round(slant / height * y1)
		else
			scaledLeft = round(-bottomLeft + slant / height * y1)
		end
		scaledRight = scaledLeft + scaledWidth - 1
		dim = ((scaledRight - scaledLeft) / crawl.wallWidth * crawl.dimming) + (1.0 - crawl.dimming)

		for x1 = scaledLeft, scaledRight do
			x2 = math.floor((tw / scaledWidth) * (x1 - scaledLeft))
			r, g, b, a = image:getPixel(x2, y2)
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
				forwardScale = setBack / 0.1
			else
				forwardScale = setBack / (setBack + depth - 1)
			end
			local foreWidth = round(wallWidth * forwardScale)
			local foreHeight = round(wallHeight * forwardScale)
			local backScale = setBack / (setBack + depth)
			local backWidth = round(wallWidth * backScale)
			local backHeight = round(wallHeight * backScale)

			if breadth == 0 then
				-- back walls
				local leftHeight = backHeight
				local rightHeight = backHeight
				newWallData.back = {
					x = backWidth * -0.5,
					y = backHeight * -0.5,
					images = {}
				}
				for i, t in ipairs(tempWalls) do
					newWallData.back.images[i] = scaleWallImage(t, backWidth, leftHeight, rightHeight)
				end

				-- center ceilings and floors
				local horizHeight = round((foreHeight - backHeight) / 2)
				newWallData.up = {
					x = foreWidth * -0.5,
					y = foreHeight * -0.5,
					images = {}
				}
				for i, t in ipairs(tempCeilings) do
					newWallData.up.images[i] = scaleHorizImage(t, horizHeight, foreWidth, backWidth, (foreWidth - backWidth) / 2)
				end
				newWallData.down = {
					x = foreWidth * -0.5,
					y = foreHeight * 0.5 - horizHeight,
					images = {}
				}
				for i, t in ipairs(tempFloors) do
					newWallData.down.images[i] = scaleHorizImage(t, horizHeight, backWidth, foreWidth, (backWidth - foreWidth) / 2)
				end

			elseif breadth == 1 or depth > 0 then
				-- side walls
				local leftHeight = backHeight
				local rightHeight = foreHeight
				local floorHeight = round((foreHeight - backHeight) / 2)
				local wallWidth = round((foreWidth - backWidth) * ((breadth - 1) * 2 + 1) / 2)
				newWallData.side = {
					x = round(backWidth * -0.5 + backWidth * breadth),
					y = round(foreHeight * -0.5),
					images = {}
				}
				for i, t in ipairs(tempWalls) do
					newWallData.side.images[i] = scaleWallImage(t, wallWidth, leftHeight, rightHeight)
				end

				-- side ceilings and floors
				local foreCorner = round(foreWidth * -0.5 + foreWidth * breadth)
				local backCorner = round(backWidth * -0.5 + backWidth * breadth)
				newWallData.up = {
					x = backCorner,
					y = foreHeight * -0.5,
					images = {}
				}
				for i, t in ipairs(tempCeilings) do
					newWallData.up.images[i] = scaleHorizImage(t, floorHeight, foreWidth, backWidth, backCorner - foreCorner)
				end
				newWallData.down = {
					x = backCorner,
					y = foreHeight * 0.5 - floorHeight,
					images = {}
				}
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
			wall = crawl.surfaceIndexFunction("wall", wx, wy, facing)
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
			wall = crawl.surfaceIndexFunction("ceiling", wx, wy, 0)
			if wall > 0 then
				wallData = crawl.wallData[depth][math.abs(breadth)].up
				love.graphics.draw(wallData.images[wall], wallData.x * flip, wallData.y, 0, flip, 1)
			end
			wall = crawl.surfaceIndexFunction("floor", wx, wy, 0)
			if wall > 0 then
				wallData = crawl.wallData[depth][math.abs(breadth)].down
				love.graphics.draw(wallData.images[wall], wallData.x * flip, wallData.y, 0, flip, 1)
			end
		end

		-- draw contents
		wallData = crawl.wallData[depth][0].down
		local backY = wallData.y
		local floorWidth, foreHeight = wallData.images[1]:getDimensions()
		local foreY = backY + foreHeight - 1
		local backWallData = crawl.wallData[depth][0].back
		local backWidth, backHeight = backWallData.images[1]:getDimensions()
		for breadth = -drawBreadth, drawBreadth do
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

		-- draw side walls
		for breadth = -drawBreadth, drawBreadth do
			if breadth < 0 then
				-- left side
				wx = x + crawl.steps[facing][1] * depth + crawl.steps[faceLeft][1] * -breadth
				wy = y + crawl.steps[facing][2] * depth + crawl.steps[faceLeft][2] * -breadth
				wall = crawl.surfaceIndexFunction("wall", wx, wy, faceRight)
				if wall > 0 then
					wallData = crawl.wallData[depth][-breadth].side
					love.graphics.draw(wallData.images[wall], -wallData.x, wallData.y, 0, -1, 1)
				end
			elseif breadth > 0 then
				-- right side
				wx = x + crawl.steps[facing][1] * depth + crawl.steps[faceRight][1] * breadth
				wy = y + crawl.steps[facing][2] * depth + crawl.steps[faceRight][2] * breadth
				wall = crawl.surfaceIndexFunction("wall", wx, wy, faceLeft)
				if wall > 0 then
					wallData = crawl.wallData[depth][breadth].side
					love.graphics.draw(wallData.images[wall], wallData.x, wallData.y)
				end
			end

		end


	end

	love.graphics.setCanvas()
	love.graphics.origin()
	love.graphics.setDefaultFilter(filterMin, filterMag, filterAni)
end


return crawl

