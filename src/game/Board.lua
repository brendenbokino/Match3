local Class = require "libs.hump.class"
local Matrix = require "libs.matrix"
local Tween = require "libs.tween"

local Gem = require "src.game.Gem"
local Coin = require "src.game.Coin"
local Cursor = require "src.game.Cursor"
local Explosion = require "src.game.Explosion"
local Sounds = require "src.game.SoundEffects"

local Board = Class{}
Board.MAXROWS = 8
Board.MAXCOLS = 8
Board.TILESIZE = Gem.SIZE*Gem.SCALE 

local bonusFont = love.graphics.newFont(14)

function Board:init(x,y, stats)
    self.x = x
    self.y = y
    self.stats = stats
    self.cursor = Cursor(self.x,self.y,Board.TILESIZE+1)

    self.tiles = Matrix:new(Board.MAXROWS,Board.MAXCOLS)
    self.coin = nil
    local coinRow = math.random(Board.MAXROWS)
    local coinCol = math.random(Board.MAXCOLS)
    for i=1, Board.MAXROWS do
        for j=1, Board.MAXCOLS do
            if i == coinRow and j == coinCol then
                local coin = self:createCoin(i,j)
                self.tiles[i][j] = coin
                self.coin = coin
            else
                self.tiles[i][j] = self:createGem(i,j)
            end
        end -- end for j
    end -- end for i
    self:fixInitialMatrix()

    self.bonusText = {
        x = 0,
        y = 0,
        transparency = 1
    }
    self.tweenBonusText = nil
    self.tweenGem1 = nil
    self.tweenGem2 = nil
    self.explosions = {}
    self.arrayFallTweens = {}
end

function Board:reset()
    self:init(self.x, self.y, self.stats)
end

function Board:createGem(row,col)
    return Gem(self.x+(col-1)*Board.TILESIZE,
               self.y+(row-1)*Board.TILESIZE,
               math.random(4,8) )
end

function Board:createCoin(row,col)
    return Coin(self.x+(col-1)*Board.TILESIZE,
               self.y+(row-1)*Board.TILESIZE,
               math.random(3) )
end

function Board:spawnRandomCoin()
    if self.coin ~= nil then return end
    local row = math.random(Board.MAXROWS)
    local col = math.random(Board.MAXCOLS)
    local coin = self:createCoin(row, col)
    self.tiles[row][col] = coin
    self.coin = coin
end

function Board:fixInitialMatrix()
    -- First we check horizontally
    for i = 1, Board.MAXROWS do
        local same = 1 
        for j = 2, Board.MAXCOLS do -- pay attention: starts as j=2
            if self.tiles[i][j].type == self.tiles[i][j-1].type then
                same = same+1 -- counting same types
                if same == 3 then -- match 3, fix it
                    self.tiles[i][j]:nextType()
                    same = 1
                end
            else
                same = 1
            end
        end
    end    

    -- Second we check vertically
    for j = 1, Board.MAXCOLS do -- pay attention: first loop is j
        local same = 1 
        for i = 2, Board.MAXROWS do -- second loop is i
            if self.tiles[i][j].type == self.tiles[i-1][j].type then
                same = same+1 -- counting same types
                if same == 3 then -- match 3, fix it
                    self.tiles[i][j]:nextType()
                    same = 1
                end
            else
                same = 1
            end
        end
    end    
end    

function Board:update(dt)
    for i=1, Board.MAXROWS do
        for j=1, Board.MAXCOLS do
            if self.tiles[i][j] then -- tile is not nil
                self.tiles[i][j]:update(dt)
            end -- end if
        end -- end for j
    end -- end for i

    for k=#self.explosions, 1, -1 do
        if self.explosions[k]:isActive() then
            self.explosions[k]:update(dt)
        else
            table.remove(self.explosions, k)
        end -- end if
    end -- end for explosions

    for k=#self.arrayFallTweens, 1, -1 do
        if self.arrayFallTweens[k]:update(dt) then
            -- the tween has completed its job
            table.remove(self.arrayFallTweens, k)
        end
    end -- end for tween Falls

    if #self.arrayFallTweens == 0 then
        local hadMatch = self:matches()
        if not hadMatch then self.stats.combo = 0 end
        if stats.leveledUp then
            self:spawnRandomCoin()
            stats.leveledUp = false
        end
    end

    if self.tweenBonusText then
        if self.tweenBonusText:update(dt) then
            self.tweenBonusText = nil
        end
    end

    if self.tweenGem1 ~= nil and self.tweenGem2~=nil then
        local completed1 = self.tweenGem1:update(dt)
        local completed2 = self.tweenGem2:update(dt)
        if completed1 and completed2 then
            self.tweenGem1 = nil
            self.tweenGem2 = nil
            local temp = self.tiles[mouseRow][mouseCol]
            self.tiles[mouseRow][mouseCol] = self.tiles[self.cursor.row][self.cursor.col]
            self.tiles[self.cursor.row][self.cursor.col] = temp
            self.cursor:clear()
            self:matches()
        end
    end
end

function Board:draw()
    for i=1, Board.MAXROWS do
        for j=1, Board.MAXCOLS do
            if self.tiles[i][j] then -- tile is not nil
                self.tiles[i][j]:draw()
            end -- end if
        end -- end for j
    end -- end for i

    self.cursor:draw()
    
    for k=1, #self.explosions do
        self.explosions[k]:draw()
    end

    if self.tweenBonusText then
        love.graphics.setColor(1,0,1, self.bonusText.transparency) -- Magenta
        love.graphics.printf("Bonus!", bonusFont, self.bonusText.x - 30, self.bonusText.y + 20, 120,"center", math.rad(-20))
        love.graphics.setColor(1,1,1) -- White
    end
end

function Board:cheatGem(x,y)
    if x > self.x and y > self.y 
       and x < self.x+Board.MAXCOLS*Board.TILESIZE
       and y < self.y+Board.MAXROWS*Board.TILESIZE then
        -- Click inside the board coords
        local cheatRow,cheatCol = self:convertPixelToMatrix(x,y)
        self.tiles[cheatRow][cheatCol]:nextType()
    end
end

function Board:mousepressed(x,y)
    if x > self.x and y > self.y 
       and x < self.x+Board.MAXCOLS*Board.TILESIZE
       and y < self.y+Board.MAXROWS*Board.TILESIZE then
        -- Click inside the board coords
        mouseRow, mouseCol = self:convertPixelToMatrix(x,y)

        if self.cursor.row == mouseRow and self.cursor.col == mouseCol then
            self.cursor:clear()
        elseif self:isAdjacentToCursor(mouseRow,mouseCol) then
            -- adjacent click, swap gems
            self:tweenStartSwap(mouseRow,mouseCol,self.cursor.row,self.cursor.col)
        else -- sets cursor to clicked place
            self.cursor:setCoords(self.x+(mouseCol-1)*Board.TILESIZE,
                    self.y+(mouseRow-1)*Board.TILESIZE)
            self.cursor:setMatrixCoords(mouseRow,mouseCol)
        end
    
    end -- end if

end

function Board:isAdjacentToCursor(row,col)
    local adjCol = self.cursor.row == row 
       and (self.cursor.col == col+1 or self.cursor.col == col-1)
    local adjRow = self.cursor.col == col 
       and (self.cursor.row == row+1 or self.cursor.row == row-1)
    return adjCol or adjRow
end

function Board:convertPixelToMatrix(x,y)
    local col = 1+math.floor((x-self.x)/Board.TILESIZE)
    local row = 1+math.floor((y-self.y)/Board.TILESIZE)
    return row,col 
end

function Board:tweenStartSwap(row1,col1,row2,col2)
    local x1 = self.tiles[row1][col1].x
    local y1 = self.tiles[row1][col1].y

    local x2 = self.tiles[row2][col2].x
    local y2 = self.tiles[row2][col2].y

    self.tweenGem1 = Tween.new(0.3,self.tiles[row1][col1],{x = x2, y = y2})
    self.tweenGem2 = Tween.new(0.3,self.tiles[row2][col2],{x = x1, y = y1})
end

function Board:findHorizontalMatches()
    local matches = {}
    for i = 1, Board.MAXROWS do 
        local same = 1
        for j = 2, Board.MAXCOLS do
            if self.tiles[i][j].type == self.tiles[i][j-1].type then
                same = same +1
            elseif same > 2 then -- match-3+
                table.insert(matches,{row=i, col=(j-same), size=same})
                same = 1
            else -- different but no match-3
                same = 1
            end
        end -- end for j

        if same > 2 then
            table.insert(matches,{row=i, col=(Board.MAXCOLS-same+1), size=same})
            same = 1
        end
    end -- end for i

    return matches
end

function Board:findVerticalMatches()
    -- Almost the same func as findHorizontalMatches, bascially changing i for j
    local matches = {}
    for j = 1, Board.MAXCOLS do 
        local same = 1
        for i = 2, Board.MAXROWS do
            if self.tiles[i][j].type == self.tiles[i-1][j].type then
                same = same +1
            elseif same > 2 then -- match-3+
                table.insert(matches,{row=(i-same), col=j, size=same})
                same = 1
            else -- different but no match-3
                same = 1
            end
        end -- end for j

        if same > 2 then
            table.insert(matches,{row=(Board.MAXROWS+1-same), col=j, size=same})
            same = 1
        end
    end -- end for i

    return matches
end

function Board:matches()
    local horMatches = self:findHorizontalMatches()
    local verMatches = self:findVerticalMatches() 
    local hasMatches = #horMatches > 0 or #verMatches > 0
    local score = 0
    local coinRow, coinCol = -1, -1
    if self.coin then
        coinRow, coinCol = self:convertPixelToMatrix(self.coin.x, self.coin.y)
    end

    if hasMatches then -- if there are matches
        stats:comboUp()
        for k, match in pairs(horMatches) do
            local matchScore = score + 2^match.size * 10   
            for j=0, match.size-1 do
                self:explodeGem(match.row,match.col+j)
            end -- end for j        
            if match.row == coinRow and
                coinCol == match.col - 1 or coinCol == match.col + match.size 
            then
                self:explodeCoin()
                matchScore = matchScore * 1.5
            end
            score = score + matchScore
        end -- end for each horMatch

        for k, match in pairs(verMatches) do
            local matchScore = score + 2^match.size * 10   
            for i=0, match.size-1 do
                self:explodeGem(match.row+i,match.col)
            end -- end for i 

            if match.col == coinCol and
                coinRow == match.row - 1 or coinRow == match.row + match.size 
            then
                self:explodeCoin()
                matchScore = matchScore * 1.5
            end
            score = score + matchScore
        end -- end for each verMatch

        if Sounds["breakGems"]:isPlaying() then
            Sounds["breakGems"]:stop()
        end
        Sounds["breakGems"]:play()

        if self.stats.combo > 1 then
            score = score * (1 + 0.1 * self.stats.combo)
        end
        self.stats:addScore(score)

        self:shiftGems()
        self:generateNewGems()

    end -- end if (has matches)
    return hasMatches
end

function Board:explodeGem(row, col)
    local gem = self.tiles[row][col]
    if gem and not gem.exploding then
        gem.exploding = true
        local exp = Explosion()
        local color = gem:getColor()
        exp:setColor(color[1], color[2], color[3])
        exp:trigger(self.x+(col-1)*Board.TILESIZE+Board.TILESIZE/2,
                self.y+(row-1)*Board.TILESIZE+Board.TILESIZE/2)  
        table.insert(self.explosions, exp) -- add exp to our array
        self.tiles[row][col] = nil
    end
end

function Board:explodeCoin()
    if self.coin and not self.coin.exploding then
        self.bonusText.x = self.coin.x
        self.bonusText.y = self.coin.y
        self.bonusText.transparency = 1
        self.tweenBonusText = Tween.new(0.6, self.bonusText, {transparency = 0})
        local coinRow, coinCol = self:convertPixelToMatrix(self.coin.x, self.coin.y)
        self:explodeGem(coinRow, coinCol)
        self.coin = nil
        Sounds["coin"]:play()
    end
end

function Board:shiftGems() 
    for j = 1, Board.MAXCOLS do
        for i = Board.MAXROWS, 2, -1 do -- find an empty space
            if self.tiles[i][j] == nil then -- current pos is empty
            -- seek a gem on top to move here
                for k = i-1, 1, -1 do 
                    if self.tiles[k][j] ~= nil then -- found a gem
                        self.tiles[i][j] = self.tiles[k][j]
                        self.tiles[k][j] = nil
                        self:tweenGemFall(i,j) -- tween fall animation 
                        break -- ends for k loop earlier
                    end -- end if found gem
                end -- end for k
            end -- end if empty pos
        end -- end for i
    end -- end for j
end -- end function

function Board:tweenGemFall(row,col)
    local tweenFall = Tween.new(0.5,self.tiles[row][col],
            {y = self.y+(row-1)*Board.TILESIZE})
    table.insert(self.arrayFallTweens, tweenFall)
end

function Board:generateNewGems()
    for j = 1, Board.MAXCOLS do
        local topY = self.y-1*Board.TILESIZE -- y pos above the first gem 
        for i = Board.MAXROWS, 1, -1  do -- find an empty space
            if self.tiles[i][j] == nil then -- empty, create new gem & tween 
                self.tiles[i][j] = Gem(self.x+(j-1)*Board.TILESIZE,topY, math.random(4,8))
                self:tweenGemFall(i,j)
                topY = topY - Board.TILESIZE -- move y further up 
            end -- end if empty space
        end -- end for i
    end -- end for j        
end -- end function generateNewGems()

return Board