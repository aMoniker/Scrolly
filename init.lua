local Scrololo = {
  name = "Scrololo",
  version = "0.0.1",
  author = "James Greenleaf",
  license = "MIT",
  homepage = "https://github.com/aMoniker/Scrololo.spoon"
}

local log = hs.logger.new("Scrololo", "debug");

-- TODO: make these configurable
local scrollMouseButton = 2
local dragThreshold = 3
local scrollMult = 1

-- These are reset in handleOtherMouseDown, and used to determine what counts
-- as a drag (using dragThreshold) inside handleOtherMouseDragging
local scrolling = true
local totalDraggedX = 0
local totalDraggedY = 0

-- Declare these early so they can be referenced in the handler functions
local bindOtherMouseDown = nil
local bindOtherMouseUp = nil
local bindOtherMouseDownDragged = nil

local function getMouseButton(e)
  return e:getProperty(hs.eventtap.event.properties["mouseEventButtonNumber"])
end

local function handleOtherMouseDown(e)
  local mouseButton = getMouseButton(e)
  if mouseButton ~= scrollMouseButton then
    return true
  end

  -- reset these variables on every new mouseDown, so handleMouseDragged
  -- can set them and determine whether to drag based on dragThreshold
  scrolling = false
  totalDraggedX = 0
  totalDraggedY = 0

  return true
end

local function handleOtherMouseUp(e)
  local mouseButton = getMouseButton(e)
  if mouseButton ~= scrollMouseButton then
    return false
  end

  -- If it wasn't a drag, then simulate a click with that mouse button
  if not scrolling then
    bindOtherMouseDown:stop()
    bindOtherMouseUp:stop()
    hs.eventtap.otherClick(e:location(), mouseButton)
    bindOtherMouseDown:start()
    bindOtherMouseUp:start()
  end

  return true
end

local function handleScrolling(e)
  -- "paper" style scrolling
  local dx = e:getProperty(hs.eventtap.event.properties["mouseEventDeltaX"])
  local dy = e:getProperty(hs.eventtap.event.properties["mouseEventDeltaY"])
  local scroll = hs.eventtap.event.newScrollEvent(
      {dx * scrollMult, dy * scrollMult}, {}, "pixel")
  return true, {scroll}

  -- Put the mouse back in the original location - probably won't need this
  -- oldmousepos = hs.mouse.getAbsolutePosition()
  -- hs.mouse.setAbsolutePosition(oldmousepos)
end

local function handleOtherMouseDragged(e)
  local mouseButton = e:getProperty(
      hs.eventtap.event.properties["mouseEventButtonNumber"])
  if mouseButton ~= scrollMouseButton then
    return false, {}
  end

  if scrolling then
    return handleScrolling(e)
  else
    -- Keep track of how far the mouse has moved
    -- Start scroll if past the dragThreshold
    local dx = e:getProperty(hs.eventtap.event.properties["mouseEventDeltaX"])
    local dy = e:getProperty(hs.eventtap.event.properties["mouseEventDeltaY"])
    totalDraggedX = totalDraggedX + dx
    totalDraggedY = totalDraggedY + dy
    local totalDragged = math.sqrt(totalDraggedX ^ 2 + totalDraggedY ^ 2)
    if totalDragged >= dragThreshold then
      scrolling = true
    end
  end

  return false, {}
end

bindOtherMouseDown = hs.eventtap.new({hs.eventtap.event.types.otherMouseDown},
    handleOtherMouseDown)
bindOtherMouseUp = hs.eventtap.new({hs.eventtap.event.types.otherMouseUp},
    handleOtherMouseUp)
bindOtherMouseDragged = hs.eventtap.new({
  hs.eventtap.event.types.otherMouseDragged
}, handleOtherMouseDragged)

function Scrololo:init()
  log.i("init")
end

function Scrololo:start()
  log.i("start")
  bindOtherMouseDown:start()
  bindOtherMouseUp:start()
  bindOtherMouseDragged:start()
end

function Scrololo:stop()
  log.i("stop")
  bindOtherMouseDown:stop()
  bindOtherMouseUp:stop()
  bindOtherMouseDragged:stop()
end

return Scrololo
