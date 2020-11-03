local Scrolly = {
  name = "Scrolly",
  version = "0.0.1",
  author = "James Greenleaf",
  license = "MIT",
  homepage = "https://github.com/aMoniker/Scrolly"
}

local log = hs.logger.new("Scrolly", "debug");

-- TODO: make these configurable
local scrollType = "slippy" -- "paper" or "slippy"
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

-- variables used for "slippy" scrolling
local canvas = nil
local mouseDownScreen = nil -- hs.screen of last mouse down
local mouseDownLocation = nil -- location of last mouse down in absolute coords
local slippyScrollTimer = nil
local slippyScrollLocation = nil
local slippyScrollMin = 1
local slippyScrollMax = 100
local slippyScrollRange = slippyScrollMax - slippyScrollMin
local slippyScrollMaxDist = 500

local moveIconImg = hs.image.imageFromPath(
    hs.spoons.resourcePath("move-icon.png"))

local function getMouseButton(e)
  return e:getProperty(hs.eventtap.event.properties["mouseEventButtonNumber"])
end

function deleteCanvas()
  if canvas then
    canvas = canvas:delete()
  end
end

-- TODO: there's slight jitter when scrolling slowly,
-- might have to cancel events that haven't finished since last tick
-- or slow down the tick speed...
local function handleSlippyScrollTimerTick()
  if not slippyScrollLocation then
    return
  end

  -- difference between current location & original mouse down location
  local dx = mouseDownLocation.x - slippyScrollLocation.x
  local dy = mouseDownLocation.y - slippyScrollLocation.y

  -- factor in the range modifier, and the scroll multiplier
  dx = (dx / slippyScrollMaxDist) * slippyScrollRange * scrollMult
  dy = (dy / slippyScrollMaxDist) * slippyScrollRange * scrollMult

  -- the scroll event uses pixel units, so these must be integers
  dx = math.floor(dx)
  dy = math.floor(dy)

  hs.eventtap.event.newScrollEvent({dx * scrollMult, dy * scrollMult}, {},
      "pixel"):post()
end

local function startScrolling()
  if scrollType == "slippy" then
    showMoveIcon(mouseDownScreen,
        mouseDownScreen:absoluteToLocal(mouseDownLocation))
    slippyScrollTimer = hs.timer.doEvery(1 / 60, handleSlippyScrollTimerTick)
  end
  scrolling = true
end

local function stopScrolling()
  if scrollType == "slippy" then
    deleteCanvas()
    if slippyScrollTimer then
      slippyScrollTimer:stop()
    end
  end
end

function showMoveIcon(screen, location)
  deleteCanvas()
  local frame = screen:frame()
  local image_size = hs.geometry.size(50, 50)
  local image_alpha = 1.0
  local fade_in_time = 0.3
  canvas = hs.canvas.new(frame)
  canvas[1] = {
    type = "image",
    image = moveIconImg,
    frame = {
      x = location.x - (image_size.w / 2),
      y = location.y - (image_size.h / 2),
      w = image_size.w,
      h = image_size.h
    },
    imageAlpha = image_alpha
  }
  canvas:show(fade_in_time)
end

local function handleOtherMouseDown(e)
  local mouseButton = getMouseButton(e)
  if mouseButton ~= scrollMouseButton then
    return true
  end

  -- these are used in "slippy" scrolling to find the amount to scroll by
  mouseDownScreen = hs.mouse.getCurrentScreen()
  mouseDownLocation = hs.mouse.getAbsolutePosition()

  -- reset these variables on every new mouseDown, so handleMouseDragged
  -- can set them and determine whether to drag based on dragThreshold
  -- TODO: should probably be part of stopScrolling()
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

  stopScrolling()

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
  if scrollType == "paper" then
    -- "paper" style scrolling
    local dx = e:getProperty(hs.eventtap.event.properties["mouseEventDeltaX"])
    local dy = e:getProperty(hs.eventtap.event.properties["mouseEventDeltaY"])
    local scroll = hs.eventtap.event.newScrollEvent(
        {dx * scrollMult, dy * scrollMult}, {}, "pixel")
    return true, {scroll}
  elseif scrollType == "slippy" then
    -- "slippy" style scrolling
    slippyScrollLocation = e:location()
    -- slippy scrolling happens in a timer
    return false, {}
  end

  return false, {}

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
      startScrolling()
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

function Scrolly:init()
  log.i("init")
end

function Scrolly:start()
  log.i("start")
  bindOtherMouseDown:start()
  bindOtherMouseUp:start()
  bindOtherMouseDragged:start()
end

function Scrolly:stop()
  log.i("stop")
  bindOtherMouseDown:stop()
  bindOtherMouseUp:stop()
  bindOtherMouseDragged:stop()
end

return Scrolly
