crawl is a LÖVE library that draws a first-person perspective view for a grid-based dungeon crawling game.

The library distorts and rescales 2D images to provide a simulated 3D view, in the style of classic dungeon crawling games such as Eye of the Beholder or Might and Magic. You do not need to provide images of walls at various distances and angles; instead, you give the library simple 2D images of your walls, monsters, and so forth, and the library does the rest.

The library does not allow for free movement or free rotation of viewpoint. All perspectives are in the four cardinal directions (north, east, south, west) from gridded locations through the dungeon.

## Overview

You initialize the library by passing it several operating parameters, including the filenames of the images you want the library to use for:

- Dungeon walls, ceiling, and floors
- Dungeon contents such as monsters and loot

You also give the library a couple of callback functions that will return information about your dungeon.

When you want to draw a view of the dungeon, you create a Canvas and pass it to the library. The library will draw a view of your dungeon onto your Canvas. You can then draw the Canvas to the screen wherever and whenver you like.

## Quick example

The following code, if accompanied by appropriate image files, is a minimal example of how you might initialize the library and draw a simple dungeon:

```
crawl = require "crawl"

function love.load()
	crawl.init({"wall.png"}, 
		{"ceiling.png"}, 
		{"floor.png"},
		{"potion.png"},
		400, 400,
		4, 0.8, 0.5,
		surfaceIndexFunction, contentsIndexFunction)
	canvasReady = false
	crawlCanvas = love.graphics.newCanvas()
end

function love.draw()
	if not canvasReady then
		crawl.draw(crawlCanvas, 0, 0, 1)
		canvasReady = true
	end
	love.graphics.draw(crawlCanvas)
end

function surfaceIndexFunction(x, y, face)
	if face < 5 then
		if y % 2 == 0 and x % 2 == 1 and (face == 1 or face == 3) then
			return 1
		elseif y % 2 == 1 and x % 2 == 0 and (face == 2 or face == 4) then
			return 1
		end
		return 0
	end
	return 1
end

function contentsIndexFunction(x, y)
	if x % 2 == 0 and y % 2 == 0 then
		return {{1, 0.5, 0.1}}
	end
	return nil
end

```

## Fuller example

The example game in this repository (represented by main.lua, conf.lua, and everything in the assets folder) provides a more detailed demonstration of the library. The controls appear in the lower right corner of the screen; use your mouse to click them or press the indicated keys. Use the attack (sword) action to destroy a monster; use the interact (hand) action to open or close doors or pick up loot. It's not a proper game (the objects you pick up don't do anything and there's no combat system) but it demonstrates walking, turning, indoor and outdoor environments, loot and monsters, and light dimming at a distance.

## Including in your project

Add crawl.lua to your project directory and add the following statement to your code:

```
crawl = require "crawl"
```

Modify this statement appropriately if you wish to put crawl.lua in a different directory.

## Directions and coordinates

The library expects to draw a grid-based dungeon, where x and y coordinates can describe the location of a square within the dungeon, and where walls potentially appear between squares. Walls do not have their own coordinates; they merely separate squares.

The four cardinal directions relate to dungeon coordinates as follows:

- **North** is along the negative y axis.
- **East** is along the positive x axis.
- **South** is along the positive y axis.
- **West** is along the negative x axis.

The library refers to north as direction number 1, east as 2, south as 3, and west as 4. In addition, the surfaceIndexFunction callback refers to the ceiling as direction 5, and the floor as 6.

## Library functions

**crawl.init(wallTextures, ceilingTextures, floorTextures, contentsTextures, wallWidth, maxDepth, setBack, dimming, surfaceIndexFunction, contentsIndexFunction)**

- **wallTextures**: an array of the filenames of the images you'll use as walls.
- **ceilingTxtures**: an array of the filenames of the images you'll use as ceilings.
- **floorTextures**: an array of the filenames of the images you'll use as floors.
- **contentsTextures**: an array of the filenames of the images you'll use for dungeon contents such as monsters and loot.
- **wallWidth**: the desired visible width, in pixels, of a wall directly in front of the player. This does not have to match the size of the images you provided as wallTextures; the library will rescale images as necessary.
- **maxDepth**: the maximum distance, measured in dungeon squares, that the library will draw.
- **setBack**: this fine-tuning parameter represents how far back in the square the player's point of view should be. This is a floating point value between 0.1 and 1.0, where 0.1 means the point of view is close to the forward edge of the square, and 1.0 means the point of view is at the rear edge. Try using a value of 0.8 to start with, and tweak it to provide the effect you like.
- **dimming**: this value sets the strength of an effect that causes surfaces to appear dimmer the further they are from the viewpoint. A value of 0.0 represents no dimming; 1.0 represents maximum dimming.
- **surfaceIndexFunction**: the name of a callback function the library will call to retrieve information about your dungeon walls. See the **Callback functions** section of this README for further information.
- **contentsIndexFunction**: the name of a callback function the library will call to retrieve information about the contents of your dungeon. See the **Callback functions** section of this README for further information.

Call this to give the library the data it needs to draw your dungeon. The function might take a little time to complete, so you may wish to display a "please wait" message before calling it.

You must call this function before you call crawl.draw(). If your entire dungeon uses the same set of images and drawing parameters, you might only need to call this function once. However, if your dungeon contains areas with visually different environments (for example, if you have outdoor areas and indoor areas) you could call this function whenever you move between areas to change which images the library uses. The benefit of this approach is that you conserve memory by giving the library only the images it needs to draw the current area, rather than feeding it images it won't use in the current area. The cost of this approach is the delay you cause every time you call crawl.init().

**crawl.draw(canvas, x, y, facing)**

- **canvas**: the Canvas you want the view drawn on. This doesn't have to be the full size of your game screen or window.
- **x**: the x coordinate of the dungeon square where the viewpoint is located.
- **y**: the y coordinate of the dungeon square where the viewpoint is located.
- **facing**: the direction the viewpoint facing (1=north, 2=east, 3=south, 4=west).

Call this when you want the library to draw a view of the dungeon from a given position.

It is not necessary to call this function every frame. Only call this when you need to update the player's view of the dungeon (for example, if the player moves, or if some of the dungeon's contents move).

**crawl.leftFaceFrom(face)**
**crawl.rightFaceFrom(face)**

The library uses these functions internally, but you can use them as well. Each accepts a number indicating a cardinal direction (1=north, 2=east, 3=south, 4=west) and returns the number of the direction to the left or to the right of the passed direction.

## Callback functions

You must write these functions yourself and pass their names to crawl.init. You may rename this functions to whatever you like, but preserve the parameters and the return values.

For both functions, the library will pass you the coordinates of a square within the dungeon, and you must return information about the image or images you want the library to draw at these coordinates. When you return the numerical index of an image, this index refers to the order in which your images appeared in the image arrays that you passed to crawl.init.

**surfaceIndexFunction(x, y, face)**

- **x**: the x position of the surface you should return.
- **y**: the y position of the surface you should return.
- **face**: This will be the face of the dungeon square you should return an image index for (1=north, 2=east, 3=south, 4=west, 5=ceiling, 6=floor).

This function describes the geometry of the dungeon. It answers the question: if you were standing at a given position and looking in a given direction, what would the wall immediately in front of you look like?

The function must return the numerical index of a wall, floor, or ceiling image corresponding to a given dungeon square. If there's no wall at the given coordinates and facing, the function must return 0.

**contentsIndexFunction(x, y)**

- **x**: the x position of the square whose contents you should return.
- **y**: the y position of the square whose contents you should return.

This function describes the contents of a given square of the dungeon. It answers the question: if you were standing at a given position, what would the contents of the square at your position look like?

The function must return an array, each element of which is an array with three fields: 

- the numerical index of a dungeon contents image
- the horizontal position of the object within the dungeon square (0.0 being far left, 1.0 being far right)
- the depth of the object within the dungeon square (0.0 being far back, 1.0 being far forward)

If the indicated dungeon square is empty, the function should return either an empty array or nil.

For example, if the function returns {{3, 0.5, 0.5}}, this indicates that the dungeon square contains an object whose image is third in the contents array, and that the object sits dead center in the middle of the square. If the function returns {{1, 0.4, 0.1},{4, 0.6, 0.1}}, this indicates that the square contains two objects, one with image index 1 and one with image index 4, sitting side by side near the rear of the square.

## Constants

The library uses these constant values internally, but they may be useful to your game as well.

**crawl.steps**

This is a four-element array, each element corresponding to one of the cardinal directions (1=north, 2=east, 3=south, 4=west). Each element contains an array with a pair of values, representing the change in x and y dungeon coordinates for a single step in that direction. For example, crawl.steps[1] = {0, -1}, indicating that a single step north subtracts 1 from your y coordinate.

## Dependencies

No additional libraries are necessary.

