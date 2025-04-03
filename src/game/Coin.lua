local Class = require "libs.hump.class"
local Anim8 = require "libs.anim8"

local spritesheet = love.graphics.newImage(
    "graphics/sprites/coin_gem_spritesheet.png")
local spriteGrid = Anim8.newGrid(16,16,spritesheet:getWidth(),spritesheet:getHeight())

local Coin = Class{}
Coin.SIZE = 16
Coin.SCALE = 2.25
Coin.Colors = {
    {255, 255, 0}, -- Yellow
    {133, 149,161},  -- Gray
    {255, 0, 0},  -- Red
}
function Coin:init(x,y,type)
    self.x = x
    self.y = y
    self.type = type 
    self.exploding = false
    if self.type == nil then self.type = 1 end

    self.animation = Anim8.newAnimation(spriteGrid('1-4',self.type), 0.25)
end

function Coin:setType(type)
    self.type = type
    self.animation = Anim8.newAnimation(spriteGrid('1-4',self.type), 0.25)
end

function Coin:nextType()
    local newtype = self.type+1
    if newtype > 3 then newtype = 1 end
    self:setType(newtype)
end

function Coin:getColor()
    return Coin.Colors[self.type]
end

function Coin:update(dt)
    self.animation:update(dt)
end

function Coin:draw()
    self.animation:draw(spritesheet, self.x, self.y, 0, Coin.SCALE, Coin.SCALE)
end

return Coin
