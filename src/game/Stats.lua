local Class = require "libs.hump.class"
local Timer = require "libs.hump.timer"
local Tween = require "libs.tween" 
local Sounds = require "src.game.SoundEffects"

local statFontSize = 25
local statFont = love.graphics.newFont(statFontSize)

local Stats = Class{}
function Stats:init()
    self.y = 10 -- we will need it for tweening later
    self.level = 1 -- current level    
    self.totalScore = 0 -- total score so far
    self.targetScore = 1000
    self.maxSecs = 99 -- max seconds for the level
    self.elapsedSecs = 0 -- elapsed seconds
    self.timeOut = false -- when time is out

    self.tweenLevel = nil -- for later
    self.tweenCombo1 = nil
    self.tweenCombo2 = nil
    self.comboText = {
        size = 1,
        orientation = 0,
    }

    self.highScore = 0
    self.combo = 0
    self.leveledUp = false
end

function Stats:reset()
    local highScore = self.highScore
    self:init()
    self.highScore = highScore
end

function Stats:draw()
    if self.y > 10 then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, self.y - 10, gameWidth, statFontSize * 2)
    end

    love.graphics.setColor(1,0,1) -- Magenta
    love.graphics.printf("Level "..tostring(self.level), statFont, gameWidth/2-60,self.y,100,"center")
    
    if self.combo > 1 then
        love.graphics.printf("COMBO!\n" .. 1 + 0.1 * self.combo .. "x", statFont, 0, gameHeight / 2 - 60, 120,"center", 
                            math.rad(self.comboText.orientation), self.comboText.size, self.comboText.size)
    end
    if self.y <= 10 then
        love.graphics.printf("Time: "..tostring(math.floor(self.elapsedSecs)).."/"..tostring(self.maxSecs), statFont,10,10,200)
        love.graphics.printf("Score: "..tostring(self.totalScore), statFont,gameWidth-210,10,200,"right")
    end
    love.graphics.setColor(1,1,1) -- White
end
    
function Stats:update(dt) -- for now, empty function
    if self.tweenLevel then
        if self.tweenLevel:update(dt) then
            self.tweenLevel = nil
        end
    end

    if self.tweenLevel then
        if self.tweenLevel:update(dt) then
            self.tweenLevel = nil
        end
    end

    if self.tweenCombo1 then
        if self.tweenCombo1:update(dt) then
            self.tweenCombo1 = nil
        end
    else
        if self.tweenCombo2 then
            if self.tweenCombo2:update(dt) then
                self.tweenCombo2 = nil
            end
        end
    end

    self.elapsedSecs = self.elapsedSecs + dt
    if self.elapsedSecs >= self.maxSecs then
        self.timeOut = true
    end
end

function Stats:addScore(n)
    local leveledUp = false
    self.totalScore = self.totalScore + n
    if self.totalScore > self.targetScore then
        self:levelUp()
        leveledUp = true
    end
    if self.totalScore > self.highScore then
        self.highScore = self.totalScore
    end
    return leveledUp
end

function Stats:comboUp()
    self.combo = self.combo + 1
    if not self.tweenCombo1 and not self.tweenCombo2 then
       self.tweenCombo1 = Tween.new(0.1, self.comboText, {size = 1.25})
       self.tweenCombo2 = Tween.new(0.1, self.comboText, {size = 1})
       if self.comboText.orientation > 0 then
        self.comboText.orientation = math.random(-22, -10)
       else
        self.comboText.orientation = math.random(10, 22)
       end
    end
end

function Stats:levelUp()
    self.level = self.level +1
    self.targetScore = self.targetScore+self.level*1000
    self.elapsedSecs = 0
    self.y = gameHeight / 2
    self.tweenLevel = Tween.new(1, self, {y = 10})
    self.leveledUp = true
    Sounds["levelUp"]:play()
end
    
return Stats
    