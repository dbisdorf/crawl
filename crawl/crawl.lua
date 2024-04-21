-- TO DO
-- don't reduce setback below ?
-- precalculations at depth 0 seem slow
-- should dimming be a color instead? like we overlay the texture color with the dimming color * intensity?
-- organization: separate private from public functions
-- example dungeon shows sky beyond depth 3
-- example should allow pickup/attack

local crawl = {}

crawl.steps = {{0,-1},{1,0},{0,1},{-1,0}}

function crawl.round(float)
	return math.floor(float + 0.5)
end

function crawl.leftFaceFrom(face)
	return (face - 2) % 4 + 1
end

function crawl.rightFaceFrom(face)
	return face % 4 + 1
end

function crawl.init(wallTextures, ceilingTextures, floorTextures, contentsTextures, wallWidth, wallHeight, maxDepth, setBack, dimming, surfaceIndexFunction, contentsIndexFunction)
	local tempWalls = {}
	for i, t in ipairs(wallTextures) do
		tempWalls[i] = love.image.newImageData(t)
	end
	local tempCeilings = {}
	for i, t in ipairs(ceilingTextures) do
		tempCeilings[i] = love.image.newImageData(t)
	end
	local tempFloors = {}
	for i, t in ipairs(floorTextures) do
		tempFloors[i] = love.image.newImageData(t)
	end
	crawl.contentsTextures = {}
	for i, t in ipairs(contentsTextures) do
		crawl.contentsTextures[i] = love.graphics.newImage(t)
	end
	crawl.skyTexture = nil

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
			local foreWidth = crawl.round(wallWidth * forwardScale)
			local foreHeight = crawl.round(wallHeight * forwardScale)
			local backScale = setBack / (setBack + depth)
			local backWidth = crawl.round(wallWidth * backScale)
			local backHeight = crawl.round(wallHeight * backScale)
			-- print(string.format("depth %d forwardScale %f backScale %f backHeight %d", depth, forwardScale, backScale, backHeight))

			if breadth == 0 then
				-- back walls
				local leftHeight = backHeight
				local rightHeight = backHeight
				newWallData.back = {
					x = backWidth * -0.5,
					y = backHeight * -0.5,
					textures = {}
				}
				for i, t in ipairs(tempWalls) do
					-- print(t:getDimensions())
					newWallData.back.textures[i] = crawl.scaleWallTexture(t, backWidth, leftHeight, rightHeight)
				end

				-- center ceilings and floors
				local horizHeight = crawl.round((foreHeight - backHeight) / 2)
				newWallData.up = {
					x = foreWidth * -0.5,
					y = foreHeight * -0.5,
					textures = {}
				}
				for i, t in ipairs(tempCeilings) do
					newWallData.up.textures[i] = crawl.scaleHorizTexture(t, horizHeight, foreWidth, backWidth, (foreWidth - backWidth) / 2)
				end
				newWallData.down = {
					x = foreWidth * -0.5,
					y = foreHeight * 0.5 - horizHeight,
					textures = {}
				}
				for i, t in ipairs(tempFloors) do
					newWallData.down.textures[i] = crawl.scaleHorizTexture(t, horizHeight, backWidth, foreWidth, (backWidth - foreWidth) / 2)
				end

			elseif breadth == 1 or depth > 0 then
				-- side walls
				local leftHeight = backHeight
				local rightHeight = foreHeight
				local floorHeight = crawl.round((foreHeight - backHeight) / 2)
				local wallWidth = crawl.round((foreWidth - backWidth) * ((breadth - 1) * 2 + 1) / 2)
				newWallData.side = {
					x = crawl.round(backWidth * -0.5 + backWidth * breadth),
					y = crawl.round(foreHeight * -0.5),
					textures = {}
				}
				-- print(string.format("depth %d breadth %d backWidth %d foreWidth %d x %d wallwidth %d", depth, breadth, backWidth, foreWidth, newWallData.side.x, wallWidth))
				for i, t in ipairs(tempWalls) do
					newWallData.side.textures[i] = crawl.scaleWallTexture(t, wallWidth, leftHeight, rightHeight)
				end

				-- side ceilings and floors
				local foreCorner = crawl.round(foreWidth * -0.5 + foreWidth * breadth)
				local backCorner = crawl.round(backWidth * -0.5 + backWidth * breadth)
				newWallData.up = {
					x = backCorner,
					y = foreHeight * -0.5,
					textures = {}
				}
				for i, t in ipairs(tempCeilings) do
					newWallData.up.textures[i] = crawl.scaleHorizTexture(t, floorHeight, foreWidth, backWidth, backCorner - foreCorner)
					-- print(string.format("depth %d breadth %d textures %d", depth, breadth, #newWallData.up.textures))
					-- print(newWallData.up.textures[i])
				end
				newWallData.down = {
					x = backCorner,
					y = foreHeight * 0.5 - floorHeight,
					textures = {}
				}
				for i, t in ipairs(tempFloors) do
					newWallData.down.textures[i] = crawl.scaleHorizTexture(t, floorHeight, backWidth, foreWidth, foreCorner - backCorner)
				end
			end

			crawl.wallData[depth][breadth] = newWallData
		end
	end

end

function crawl.setSkyTexture(texture)
	if texture == nil then
		crawl.skyTexture = nil
	else
		crawl.skyTexture = love.graphics.newImage(texture)
		local skyW, skyH = crawl.skyTexture:getDimensions()
		local skyFaceW = crawl.round(skyW / 4)
		crawl.skyQuads = {}
		for i = 1, 4 do
			crawl.skyQuads[i] = love.graphics.newQuad((i - 1) * skyFaceW, 0, skyFaceW, skyH, crawl.skyTexture)
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
	if crawl.skyTexture ~= nil then
		local skyX, skyY, skyW, skyH = crawl.skyQuads[facing]:getViewport()
		local skyScale = ch / skyH
		love.graphics.draw(crawl.skyTexture, crawl.skyQuads[facing], 0, 0, 0, skyScale, skyScale, crawl.round(skyW / 2), crawl.round(skyH / 2))
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
				-- i only have back face wall data for the straight-ahead cells
				wallData = crawl.wallData[depth][0].back
				local ww, wh = wallData.textures[wall]:getDimensions()
				love.graphics.draw(wallData.textures[wall], wallData.x + ww * breadth, wallData.y)
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
				-- print(string.format("%d %d %d", depth, breadth, #wallData.textures))
				love.graphics.draw(wallData.textures[wall], wallData.x * flip, wallData.y, 0, flip, 1)
			end
			wall = crawl.surfaceIndexFunction("floor", wx, wy, 0)
			if wall > 0 then
				wallData = crawl.wallData[depth][math.abs(breadth)].down
				love.graphics.draw(wallData.textures[wall], wallData.x * flip, wallData.y, 0, flip, 1)
			end
		end

		-- draw contents
		wallData = crawl.wallData[depth][0].down
		local backY = wallData.y
		local floorWidth, foreHeight = wallData.textures[1]:getDimensions()
		local foreY = backY + foreHeight - 1
		local backWallData = crawl.wallData[depth][0].back
		local backWidth, backHeight = backWallData.textures[1]:getDimensions()
		for breadth = -drawBreadth, drawBreadth do
			wx = x + crawl.steps[facing][1] * depth + crawl.steps[faceRight][1] * breadth
			wy = y + crawl.steps[facing][2] * depth + crawl.steps[faceRight][2] * breadth
			local contents = crawl.contentsIndexFunction(wx, wy)
			if contents ~= nil then
				for i, c in ipairs(contents) do
					local cy = crawl.round((foreY - backY) * c[3] + backY)
					local cw = crawl.round((floorWidth - backWidth) * c[3] + backWidth)
					local cx = (cw * -0.5) + (cw * breadth) + (cw * c[2])
					local ctw, cth = crawl.contentsTextures[c[1]]:getDimensions()
					local cScale = crawl.setBack / (crawl.setBack + depth - 1 + (1.0 - c[3]))
					-- print(string.format("cx %d cy %d scale %f w %d h %d", cx, cy, wallData.scale, crawl.round(ctw/2), cth))
					love.graphics.draw(crawl.contentsTextures[c[1]], cx, cy, 0, cScale, cScale, crawl.round(ctw / 2), cth)
				end
			end
		end

		-- draw side walls
		for breadth = -drawBreadth, drawBreadth do
			-- print(string.format("D %d B %d", depth, breadth))
			if breadth < 0 then
				-- left side
				wx = x + crawl.steps[facing][1] * depth + crawl.steps[faceLeft][1] * -breadth
				wy = y + crawl.steps[facing][2] * depth + crawl.steps[faceLeft][2] * -breadth
				wall = crawl.surfaceIndexFunction("wall", wx, wy, faceRight)
				-- print(string.format("wx %d wy %d", wx, wy))
				if wall > 0 then
					-- print("draw left")
					wallData = crawl.wallData[depth][-breadth].side
					-- print(depth .. " " .. breadth .. " " .. crawl.wallData[3][1].side.x)
					-- print("left side wall " .. wallData.x .. " " .. wallData.y)
					love.graphics.draw(wallData.textures[wall], -wallData.x, wallData.y, 0, -1, 1)
				end
			elseif breadth > 0 then
				-- right side
				wx = x + crawl.steps[facing][1] * depth + crawl.steps[faceRight][1] * breadth
				wy = y + crawl.steps[facing][2] * depth + crawl.steps[faceRight][2] * breadth
				wall = crawl.surfaceIndexFunction("wall", wx, wy, faceLeft)
				-- print(string.format("wx %d wy %d", wx, wy))
				if wall > 0 then
					-- print("draw right")
					wallData = crawl.wallData[depth][breadth].side
					love.graphics.draw(wallData.textures[wall], wallData.x, wallData.y)
				end
			end

		end


	end

	love.graphics.setCanvas()
	love.graphics.origin()
	love.graphics.setDefaultFilter(filterMin, filterMag, filterAni)
end

function crawl.scaleWallTexture(texture, width, leftHeight, rightHeight)
	local tw, th = texture:getDimensions()
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
			--x2 = crawl.round(math.sqrt(1 - ((width - x1) / width) * ((width - x1) / width)) * tw)
			x2 = math.floor(math.log(x1 / width * 3.0 + 1.0, 4) * tw)
		else
			x2 = math.floor(tw / width * x1)
		end
		scaledHeight = crawl.round((rightHeight - leftHeight) / width * x1 + leftHeight)
		-- print(string.format("leftHeight %d rightHeight %d width %d x1 %d x2 %d", leftHeight, rightHeight, width, x1, x2))
		scaledTop = (height - scaledHeight) / 2
		scaledBottom = scaledTop + scaledHeight - 1
		-- print(string.format("height %d scaledHeight %d scaledTop %d scaledBottom %d", height, scaledHeight, scaledTop, scaledBottom))
		dim = ((scaledBottom - scaledTop) / crawl.wallHeight) * crawl.dimming + (1.0 - crawl.dimming)

		for y1 = scaledTop, scaledBottom do
			y2 = math.floor((th / scaledHeight) * (y1 - scaledTop))
			-- print(string.format("%d %d %d %d %d %d", x1, y1, x2, y2, width, height))
			r, g, b, a = texture:getPixel(x2, y2)
			scaleImage:setPixel(x1, y1, r * dim, g * dim, b * dim, a)
		end
	end

	return love.graphics.newImage(scaleImage)
end

function crawl.scaleHorizTexture(texture, height, topWidth, bottomWidth, slant)
	local tw, th = texture:getDimensions()
	local topLeft = 0
	local topRight = topWidth - 1
	local bottomLeft = slant
	local bottomRight = bottomWidth + slant - 1
	local width = math.max(topRight, bottomRight) - math.min(topLeft, bottomLeft) + 1
	-- print(string.format("scale to w %d h %d", width, height))
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
		scaledWidth = crawl.round((bottomWidth - topWidth) / height * y1 + topWidth)
		-- scaledLeft = crawl.round((bottomLeft - topLeft) / height * y1 + topLeft)
		-- so the question of scaledLeft is different in this method
		-- it either starts at 0 and shifts right as we go (if bottomLeft >= 0)
		-- or starts indented and shifts left until it reaches zero (if bottomLeft < 0)
		if bottomLeft >= 0 then
			scaledLeft = crawl.round(slant / height * y1)
		else
			scaledLeft = crawl.round(-bottomLeft + slant / height * y1)
		end
		scaledRight = scaledLeft + scaledWidth - 1
		dim = ((scaledRight - scaledLeft) / crawl.wallWidth * crawl.dimming) + (1.0 - crawl.dimming)

		for x1 = scaledLeft, scaledRight do
			x2 = math.floor((tw / scaledWidth) * (x1 - scaledLeft))
			-- print(string.format("topleft %d topright %d bottomleft %d bottomright %d width %d height %d x1 %d y1 %d x2 %d y2 %d", topLeft, topRight, bottomLeft, bottomRight, width, height, x1, y1, x2, y2))
			r, g, b, a = texture:getPixel(x2, y2)
			scaleImage:setPixel(x1, y1, r * dim, g * dim, b * dim, a)
		end
	end

	return love.graphics.newImage(scaleImage)
end

return crawl

