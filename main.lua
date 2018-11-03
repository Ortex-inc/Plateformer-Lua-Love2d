-- macros

width = 700
height = 540
path =  "assets/all/"

-- attractive forces
g = 0.85
f = 1.34

default = love.graphics.newFont("retro.ttf", 16)
big = love.graphics.newFont("retro.ttf", 30)

canvas = love.graphics.newCanvas( width, height )
--love.graphics.setCanvas(canvas)
  
-- POO simulation
function new(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[new(orig_key)] = new(orig_value)
        end
        setmetatable(copy, new(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end
--end
filtre = {}
filtre.retro = love.graphics.newShader [[
vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ){
  vec4 pixel = Texel(texture, texture_coords );
  
  //This is the current pixel color
  number average = (pixel.r+pixel.b+pixel.g)/3.0;
  pixel.r = average;
  pixel.g = average;
  pixel.b = average;
  return pixel;
}
]]
function filtre.apply(this,condition)
if condition then love.graphics.setShader(this) end
end
function filtre.finish(condition)
	if condition then love.graphics.setShader() end
end

menu = {start = {} , fail = {} }

game = { init = nil , charge = nil ,update = nil, draw = nil , stat = "inGame"}  

memory = {}

map = {x = 0 ,y = 0 ,w = 0 , h = 0,line = 0 , row = 0 ,tile = 32, element = {} , method = {} }

button = {x = nil,y = nil,w = nil,h = nil , label = nil, ox = 1 , oy = 1 , method = {}}

mouse = {x = 0, y = 0 , h = 1 , w = 1,  hold = nil ,method = {}, rightClick =  false , leftClick = false}

---------------------------------- heritats
function myloadstring(s, name)
	local f, err = loadstring("return function (d,s) "..s.." end", name or s)
	return f and f() or f, err 
end

function addAbility(d, s)
	for e in pairs(s) do
	myloadstring(' d.'..e..' = s.'..e )(d,s)
	end
end
---------------------------------------
timer = {}
timer.time = 1.5
timer.init = function(self) self.time = 1.5 end 
timer.timeout = function(self,dt) 
	self.time = math.max(self.time - dt, 0)
	return self.time == 0
end
	-- animations
	scaling = {}
	scaling.eps = 0.005
	addAbility(scaling , timer)
	scaling.time = 0.6
	scaling.on = function(self,dt)
	if self.timeout(self,dt) then self.time = 0.6 ; self.eps = - self.eps end
	self.ox = self.ox + self.eps
	self.oy = self.oy + self.eps
	end

------------
	fadein = {}
	addAbility(fadein , timer)
	fadein.play = function(self,dt)
		local eps = 0.05
		if self.time > 0 then
		self.timeout(self,dt)
		self.ox = math.max(self.ox  - eps , 0)
		self.oy = math.max(self.oy  - eps , 0)
		self.x = self.x + (self.w * eps)/2
		self.y = self.y + (self.h * eps)/2
		return true
		else return false end
	end

	crush = {}
	addAbility(crush , timer)
	crush.play = function(self,dt)
		local eps = 0.05
		if self.time > 0 then
		self.timeout(self,dt)
		self.ox = self.dir * math.min( math.abs(self.ox)  + eps, self.h/4)
		self.oy = math.max(self.oy  - eps , 0)
		self.x = self.x - (self.w * eps)/2
		self.y = self.y + (self.h * eps)
		return true
		else return false end
	end
---------------------------------input
	input = {}
	input.can = {}
	--orientations
	input.can.up = true
	input.can.down = true
	input.can.left = true
	input.can.right = true
--------------------------------- objects
	elm = { x = 0, y = 0, h = 0, w = 0 }
	elm.surface = nil
	elm.quad = nil
	elm.img = ""
	elm.ox = 1
	elm.oy = 1
	elm.plateformer = true
	elm.setQuad = function(x,y,w,h,self)
		self.quad = love.graphics.newQuad(x, y,w ,h, memory[self.img]:getDimensions())
	end
	elm.src = function (mem,self) 
		self.surface = love.graphics.newImage(self.img) 
	end

	elm.dim = function ( x ,y ,w ,h , self) 
		self.x = x
		self.y = y
		self.w = w
		self.h = h
	end

	elm.draw = function (self)
		love.graphics.draw(self.surface,self.quad, self.x ,self.y,0,1,1) 
	end
-----------------------------------
	adner = {}
	adner.stat = "stand"
	adner.speed = {}
	adner.speed.x = 1
	adner.speed.y = 1
	adner.step = 4
	adner.life = true
	adner.object = {}
	
adner.permission = function(self,action)

	if self.life then 
	
	if self.stat == "stand" then
	 return action == "jump" or action == "walk" 
	end
	
	if self.stat == "jump" then
	 return action == "walk"
	end

	if self.stat == "fall" then
	 return action == "walk"
	end
	if self.stat == "walk" then 
	return action == "walk" 
	end
	
	end

	return false
end
adner.jump = function(self)
		self.stat = "jump"
		self.speed.y = self.speed.y * f
		local vy = self.h / self.speed.y
		self.y = self.y - vy
		if vy < 1 then self.stat = "fall" end 
end

adner.stand = function (self) 
	if not (self.can.down or self.stat == "jump" or self.stat == "dead" )
	then
		self.stat = "stand"
		self.speed.x = 1
		self.speed.y = 1
		return true
	end
	return false
end

adner.run = function(self,s)
	self.speed.x = self.speed.x * f
	self.x = self.x + s * self.step
end
-----------
	clip = {}
	clip.currentTime = 0
	
	clip.animation = function(m,line, duration,dt)
		m.currentTime = m.currentTime + dt
		if m.currentTime >= duration then
		    m.currentTime = m.currentTime - duration 
			local x,y,w,h = m.quad:getViewport()
			local sw,sh = memory[m.img]:getDimensions()
			if x + w >= sw then x = 0 else  x = x + w end
			m.setQuad(x, (line-1) * h ,w, h , m)
		end
	end
	
	clip.manager = function(m,dt)
		if m.stat == "dead"  then stat.dead = true end
		if m.stat == "stand" then
			m.animation(m,1,0.3,dt)
		elseif m.stat == "jump" then 
			m.jump(m)
			m.setQuad(0,m.h,m.w,m.h,m)
		elseif m.stat == "fall" and m.speed.y <= 2 then 
			m.setQuad(m.w*2,m.h,m.w,m.h,m)
		elseif m.stat == "fall" then 
			m.setQuad(m.w,m.h,m.w,m.h,m)
		elseif m.stat == "dead" then 
			m.animation(m,3,0.4,dt)
		end
	end
------------------------
	stat = new(elm)
	stat.win = false
	stat.init = function(self)
		stat.win = false
		stat.dead = false
	end
	stat.update = function(self)
		if self.win then 
			textBox.init("Win" ,true,textBox)
		elseif self.dead then
			textBox.init("Dead" ,true,textBox)
		end
	end
	
	intel = {}
	intel.dir = -1
	intel.step = 2
	intel.verify = function(self ,map)
	
		self.can.up = true
		self.can.down = true
		self.can.left = true
		self.can.right = true
		for _,e in ipairs(map.element) do
			if self.x - e.x <= map.tile and self.x - e.x >= 0 and self.y + map.tile == e.y
				then self.can.left = inTable(e.img , ground)
				
			elseif e.x - self.x <= map.tile and e.x - self.x >= 0 and self.y + map.tile == e.y
				 then self.can.right = inTable(e.img , ground)
			end
		end
		
		if self.dir == -1 then
			if not self.can.left then self.dir = 1 ; self.ox = -1  end
		end
		if self.dir == 1 then
			if not self.can.right then self.dir = -1 ; self.ox = 1  end
		end
	end
	
	intel.push = function(self,l)
	self.stat = "push"
	if self.dir == -1 then 
		l.can.right = false ; 
		if  l.can.left == true then l.x = l.x + self.dir * self.step  
		else  self.dir = 1 ; self.ox = -1 ; self.x = self.x + l.w end
					
	elseif self.dir == 1 then
				
		l.can.left = false ;
		if  l.can.right == true then l.x = l.x + self.dir * self.step  
		else  self.dir = -1 ; self.ox = 1; self.x = self.x - l.w end 
		end
	end
	intel.walk = function(self)
		self.x = self.x + (self.dir * self.step)
	end

	textBox = new(elm)
	addAbility(textBox , timer)
	textBox.time = 1.5
	textBox.content = ""
	textBox.show = false
	--tweening faux le faire
	textBox.init = function(text,isGameStat , self)
		self.content = text
		if not isGameStat then
			textBox.dim(10,10,250,100 , self)
		else
			textBox.dim(0,height/2 - 100/2 ,width,100 , self)
		end
		self.show = true
	end
	textBox.check = function (self,dt)
		if self.show then self.timeout(self,dt) end
		if self.show and self.time == 0 then self.time = 1.5 ; self.show = false end

	end
	
	textBox.draw = function(self)
	if self.show and self.time > 0 then

	local w = self.w * self.ox 
	local h = self.h * self.oy 
	love.graphics.setColor( 0, 0, 0, 255 )
	love.graphics.rectangle("fill",self.x , self.y ,w,h)
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.setFont(big)
	love.graphics.printf(self.content, self.x + w/2 - big:getWidth(self.content)/2 , self.y + h/2 - big:getHeight(self.content)/2 , 1, "left")
		love.graphics.setFont(default)
		end
	end



particle = {}
particle.color = "black"
particle.to_x = 0
particle.to_y = 0
particle.x = 100
particle.y = 100

particle.generate = function(self,angle)
	math.randomseed(os.time())
	local radius = 64
	local pi = 3.1415
	local angle = angle * pi / 180
	self.to_x = self.x +  radius * math.sin(angle)
	self.to_y = self.y +  radius * math.cos(angle)
end

particle.translate = function(self)
	local eps = 1.5
	if math.abs( self.x - self.to_x) > eps then
		if self.to_x > self.x then self.x = self.x + eps else self.x = self.x - eps end
	end
	if math.abs( self.y - self.to_y) > eps then
	if self.to_y > self.y then self.y = self.y + eps else self.y = self.y - eps end
	end
end

particle.draw = function(self)
	local p = 8
	love.graphics.setColor(253,204,0,255)
	love.graphics.rectangle("fill",self.x,self.y,p,p)
	love.graphics.rectangle("fill",self.x+p ,self.y-p ,p ,p)
	love.graphics.rectangle("fill",self.x+p, self.y+p ,p ,p)
	love.graphics.rectangle("fill",self.x + 2*p ,self.y ,p ,p)
	love.graphics.setColor(255,255,255,255)
end

	manifest = {}
	addAbility(manifest , timer)
	manifest.n = 4
	manifest.init = function(self,x,y)
		manifest.time = 0.4
		manifest.particles = {}
		for e = 2, self.n do 
			tmp = new(particle)
			tmp.generate(tmp,360/self.n * e)
			tmp.x = x
			tmp.y = y
			table.insert(self.particles , tmp )
		end
	end
manifest.translate = function(self,dt)
	for _,e in ipairs(self.particles) do
		e.translate(e)
	end
	self.time = self.time - dt
end
	manifest.pow = function(self)
		if self.time > 0 and self.time < 0.4 then
		for _,e in ipairs(self.particles) do
			e.draw(e)
		end
		return true
		else return false end
	end
	
	dust = {}
	addAbility(dust , timer)
	addAbility(dust , particle)
	dust.time = 0.3
	dust.x = -1
	dust.y = -1
	dust.init = function(self,x,y)
		self.x = x + 32
		self.y = y + 24
	end
	
	dust.appear = function(self,dir,dt)
	if not self.timeout(self,dt) 
	then self.x =  self.x + dir end
	end
dust.draw = function(self)
	if self.time < 0.3 then
	local p = 8
	love.graphics.setColor(120,120,120,255)
	love.graphics.rectangle("fill",self.x,self.y,p,p)
	love.graphics.rectangle("fill",self.x+p ,self.y-p ,p ,p)
	love.graphics.rectangle("fill",self.x + 2*p ,self.y ,p ,p)
	love.graphics.setColor(255,255,255,255)
	end
end
---------------------------------
mouse.method.on = function(self,m)
return self.x >= m.x and self.x <= m.x + m.w and self.y >= m.y and self.y <= m.y + m.h
end
mouse.method.init = function(self) 	
	mouse.leftClick = false 
	mouse.rightClick = false 
end
mouse.method.update = function(self)
	self.x = love.mouse.getX()
	self.y = love.mouse.getY()
end
---------------------------
map.method.init = function (row,line,tile,self)
	self.line = line
	self.row = row
	self.tile = tile
	self.x = 0
	self.y = 0
	self.w = tile * row
	self.h = tile * line
end

map.method.create = function (self)
	for i=0,self.line do
		for j=0,self.row  do
			local e = new(elm)
			e.dim( (self.x + self.tile * j),(self.y + self.tile * i), self.tile, self.tile, e)
			e.img = ""
			table.insert(self.element,e)
		end
	end
end

map.method.draw = function (mem, self)
	for _,k in ipairs(self.element) do
		if not (k.img == "" or k.img == nil ) then 
			if mem[k.img] ~= nil then
				local fix_x = k.x if k.ox == -1 then fix_x = k.x  + k.w end
				local fix_y = k.y if k.oy == -1 then fix_y = k.y  + k.h end
				love.graphics.draw( mem[k.img] ,k.quad, fix_x ,fix_y ,0 ,k.ox ,k.oy)
			end 
		end		
	end
end
------------------------------
	button.method.init = function (label,x,y,w,h,self)
	self.w = w
	self.h = h
	self.x = x
	self.y = y
	self.label = label
end

button.method.onclick = function(self,mouse,callback)
	if mouse.leftClick and mouse.method.on(mouse,self) then
	callback()
	end
end
button.method.draw = function(self)
	love.graphics.setFont(default)
	local w = self.w * self.ox 
	local h = self.h * self.oy 
	love.graphics.setColor( 0, 0, 0, 255 )
	love.graphics.rectangle("fill",self.x , self.y ,w,h)
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.printf(self.label, self.x + w/2 - default:getWidth(self.label)/2 , self.y, 0, "left")
end
---------------------------------
function detection (l,m) 
		if l.y + l.h >= m.y and l.y + l.h <= m.y + m.h and
		math.abs(l.x - m.x) - math.min(l.w , m.w) < 0
		
		then l.y = m.y - l.h
		l.can.down = false 
		end

		if l.y > m.y  and l.y < m.y + m.h and
		math.abs(l.x - m.x) - math.min(l.w , m.w) < 0 and not m.plateformer
		then
		l.y = m.y + m.h
		l.can.up = false
		end
		if l.x > m.x and l.x < m.x + m.w and
		math.abs(l.y - m.y) - math.min(l.h , m.h) < 0
		then 
		l.can.left = false 
		end
		
		if l.x + l.w >= m.x and l.x + l.w <= m.x + m.w and
		math.abs(l.y - m.y) - math.min(l.h , m.h) < 0

		then  
		l.can.right = false
		end
		return not (l.can.right and l.can.left and l.can.up and l.can.down)
end

function inTable(i, t)
    for _,e in ipairs(t) do
        if e == i then return true end
    end
    return false
end

function rmTable(i, t)
    for k,v in pairs(t) do
		if type(k) == "number" then
		    if t[k] == i then  t[k] = nil end 
		elseif  k == i then  t[k] = nil end
    end
    return t
end

function interact(l,map)
	--free step
	l.can.up = true
	l.can.down = true
	l.can.left = true
	l.can.right = true 
	
	for i,e in ipairs(map.element) do
		if (math.abs(l.x - e.x) <= map.tile and math.abs(l.y - e.y) > 0  and math.abs(l.y - e.y) <= map.tile ) or 
			(math.abs(l.y - e.y) <= map.tile and math.abs(l.x - e.x) > 0 and math.abs(l.x - e.x) <= map.tile )then
			if e.img == path.."block.png" then
				e.plateformer = false
			end
			-- block crossing ground
			if inTable(e.img , ground) then
				detection(l,e)		
			end
			-- pushers
			if e.img == pusher.img and detection(l,e) then
				e.push(l,e)
			end
			--items
			if e.token == false then
				l.object = e
				e.token = true
			end
			-- exclamation
			if (e.img == path.."exclamation.png") and
			detection(l,e)
			then
				textBox.init("Welcome",false,textBox)
				textBox.show = true
			end	
			if (e.img == path.."helper.png") then
			--push hero
				e.push(e,l)
			end
			if e.img == (path.."enemy.png") then
					detection(l,e)
					if not l.can.down and l.can.right and l.can.left and l.can.up then  e.life = false 
					else  
					e.push(e,l)
					l.stat = "dead" end
			end	
			if e.img == (path.."hook.png") then
				if detection(l,e) then l.stat = "dead" end
			end
		end
	end
end
	
function manager(b) 

	if love.keyboard.isDown("right") then
		if b.can.right then
			b.x = math.min (b.x , width - b.w)
			if b.permission(b,"walk") then b.run(b, 1) end
		end
	end
	if love.keyboard.isDown("left") then
		if b.can.left then
			b.x = math.max (b.x ,0)
			if b.permission(b,"walk") then b.run(b, -1) end
		end
	end
	if love.keyboard.isDown("up") then
		if b.can.up then
		if b.permission(b,"jump") then  b.jump(b)  end
		end
	end
	if love.keyboard.isDown("down") then
		if b.can.down then
			b.y = math.min ( (b.y + b.step ) , height - b.h)
		end
	end
end

function gravity(b)
	if not b.stand(b) and b.stat ~= "dead" then
		b.speed.y = b.speed.y * g
		b.y = b.y + math.min(b.step/b.speed.y,b.h/3)  end
	if b.stat ~= "dead" then 
		if b.can.down and b.stat ~= "jump" then b.stat = "fall"  end
	end
end

------ file & string operations
function split(s, delimiter)
    local result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result
end

function readAll(file)
    local f = assert(io.open(file, "rb"))
    local content = f:read("*all")
    f:close()
    return content
end
----------- import map & load resource to memory associative table
function import(mem, file)
	local tab = readAll(file)
	tab = split(tab,'@')
	local array = new(map)
	array.method.init(22,17,32,array)
	array.method.create(array)
	
	for i,k in ipairs(array.element) do 
		if not (tab[i] == '\n' or tab[i] == "" or tab[i] == nil ) then 
			k.img = tab[i]
			mem [k.img] = love.graphics.newImage(k.img)
			k.setQuad(0,0,k.w,k.h ,k)
		end
	end
	return array
end
------
function search(sprite, source)
	t = {} 
	for _,e in ipairs(source.element) do
		if e.img == sprite then 
			table.insert(t,e)
		end
	end
	return t
end

function zoom(spec)
	for e in pairs(spec) do
		print(e)
	end
end

function lastDraw(m,map)
	for i,e in pairs(map.element) do
		if e.img == (path.."hero.png") then 
		e = nil ; break
		end
	end
	table.insert(map.element,m)
end

function cleanup(tab)
	for i,e in pairs(tab) do
		if type(tab[i]) == "table" then
			cleanup(tab[i])
		else tab[i] = nil end
	end
end

--------------------
start = {}
fail = {}
menu.home = function()	

	start.inf = new(button)
	start.play = new(button)
	start.exit = new(button)
	fail.retry = new(button)
	fail.back = new(button)
	
	fail.retry.method.init("Retry",width/2-100/2,200,80,25,fail.retry)
	
	fail.back.method.init("Return",width/2-100/2,250,80,25,fail.back)

	start.play.method.init("Play",width/2-100/2,200,80,25,start.play)
	
	start.exit.method.init("Quit",width/2-100/2,250,80,25,start.exit)

	start.inf.method.init("Developped_by_Ortex-inc_2018",width/2 - 300/2 ,height -25,300,25,start.inf)
	
	addAbility(start.play , scaling)
	addAbility(start.exit , scaling)
	addAbility(fail.retry , scaling)
	addAbility(fail.back  , scaling)
end
menu.update = function(dt)
	mouse.method.update(mouse)
	
	if game.stat == "home" then
	start.play.method.onclick (start.play,mouse,(function() cleanup({tmap.element, memory}) ; game.charge() end) ) 	
	start.exit.method.onclick (start.exit,mouse,(function() cleanup({tmap.element, memory}) ; love.event.quit() end) ) 	
	
	elseif game.stat == "retry" then
	fail.retry.method.onclick (fail.retry,mouse,(function() cleanup({tmap.element, memory}) ; game.charge() end) ) 	
	fail.back.method.onclick (fail.back,mouse,(function() game.stat = "home" end) ) 	
	end
	start.exit.on(start.exit, dt)
	start.play.on(start.play, dt)
	fail.retry.on(fail.retry, dt)
	fail.back.on(fail.back, dt)
end
menu.draw = function()
	if game.stat == "home" then
		for _,e in pairs(start) do
			e.method.draw(e)
		end
	
	else
		for _,e in pairs(fail) do
			e.method.draw(e)
		end	
	end
end
------------------
game.draw = function()
   	filtre.apply(filtre.retro , (hero.stat == "dead") )
	tmap.method.draw(memory,tmap)
	manifest.pow(manifest)
	dust.draw(dust)
	filtre.finish(true)
	textBox.draw(textBox)
end

game.charge = function()
	game.stat = "inGame"
	stat.init(stat)
	timer.init(timer)
	textBox.show = false
	
	tmap = import(memory,"map.tlx")
	hero = search( path.."hero.png" , tmap )
	hero = hero[1]
	addAbility(hero, input)
	addAbility(hero , adner)
	addAbility(hero , clip)
	
	apples = search(path.."apple.png" , tmap)
	apple = {}
	apple.token = false
	apple.effect = function(self)
		stat.win = true
	end
	
	apple.check = function(self,dt,tmap)
		if self.token then
		if not self.play(self,dt) then self.img = "" ; self.effect(self) end 
		manifest.translate(manifest,dt)

		end
	end
	for _,e in ipairs (apples) do
		addAbility(e,apple)
		addAbility(e,fadein)
		manifest.init(manifest ,e.x ,e.y)
	end

	block = {}
	block.broke = false
	block.check = function(self,key,dt,tmap)
		if key.token then
			if not self.play(self,dt) then self.img = "" ; end 
		end
	end
	blocks = {}
	blocks = search(path.."block.png", tmap)
	for _,e in ipairs(blocks) do
		addAbility(e, fadein)
		addAbility(e, block)
	end
	
	ground = { 
	(path.."1.png"), (path.."2.png"), 	
	(path.."3.png"), (path.."4.png"),
	(path.."5.png"), (path.."6.png"),
	(path.."7.png"), (path.."8.png"),
	(path.."9.png"), (path.."10.png"),
	(path.."11.png"), (path.."block.png") 
			}
	
	pusher = {}
	pusher.speed = 1.2
	pusher.img = (path.."push.png")
	pusher.orientation = 'left'
	pusher.push = function(m,self)
		if self.orientation == 'left' then 
		m.speed.x = self.speed * m.speed.x ; m.run(m, -1)
		else
		m.speed.x = self.speed * m.speed.x ; m.run(m, 1)
		end
	end 
	pushers = search(path.."push.png" , tmap)
	for _,e in ipairs(pushers) do
		addAbility(e,pusher)
		addAbility(e,clip)
	end

	keys = search(path.."key.png", tmap)
	key = {}
	key.token = false
	key.effect = function(self)
		ground = rmTable( path.."block.png",ground)
		memory = rmTable(path.."block.png" ,memory)
	end
	key.check = function(self,dt,tmap)
		if self.token then
			if not self.play(self,dt) then self.img = "" ; self.effect(self) end 
		end
	end
	for _,e in ipairs (keys) do
		addAbility(e,key)
		addAbility(e,fadein)
		addAbility(e,scaling)
	end
		
	enemies = search(path.."enemy.png" , tmap)
	for _,e  in ipairs(enemies) do
		addAbility(e, adner)
		addAbility(e,input)
		addAbility(e,intel)
		addAbility(e,clip)
		addAbility(e,crush)
		e.stat = "walk"
		e.check = function(self,tmap,dt)
		if not self.life then self.play(self,dt) end 
		if e.permission(e,"walk") then e.verify(e,tmap) ; e.walk(e) end
		e.animation(e,1,0.3,dt)
	end
	end
	helpers  = search(path.."helper.png", tmap)
		for _,e  in ipairs(helpers) do
		addAbility(e, adner)
		addAbility(e,input)
		addAbility(e,intel)
		addAbility(e,clip)
		e.stat = "walk"
	end
	flowers = search(path.."flower.png",tmap)
	for _,e in ipairs(flowers) do
		addAbility(e,clip)
	end
	grasses = search(path.."grass.png",tmap)
	for _,e in ipairs(grasses) do
		addAbility(e,clip)
	end	

end

function love.load()

    love.window.setMode(width, height)
	love.graphics.setDefaultFilter("nearest")
	
	menu.home()
	game.charge()
	
end

game.update = function(dt)
	manager(hero)
	interact(hero,tmap) 
	hero.manager(hero,dt)
	gravity(hero)

-- the problem here with enemmies 
for _,e in ipairs(apples) do
	e.check(e , dt, tmap)
end

for _,e in ipairs(keys) do
	e.check(e , dt, tmap)
	e.on(e,dt)
end

for _,e in ipairs(blocks) do
	e.check(e,keys[1],dt,tmap)
end

for _,e in ipairs(flowers) do
	e.animation(e,1,0.6,dt)
end
for _,e in ipairs(grasses) do
	e.animation(e,1,0.2,dt)
end

--------------------- decor
for _,e in ipairs(enemies) do
	e.check(e,tmap,dt)
end

for _,e in ipairs(pushers) do
	e.animation(e,1,0.2,dt)
end

for _,e in ipairs(helpers) do
	e.verify(e,tmap)
	e.walk(e)
	e.animation(e,1,0.3,dt)
	if dust.time == 0 then e.stat = "walk" ; dust.time = 0.3 end
	local fix = e.x 
	if e.dir == 1 then fix = e.x - 64 end 
	if e.stat == "push" then dust.appear(dust,e.dir,dt)
	else dust.init(dust,fix,e.y) 
	end
end

stat.update(stat)
	if stat.win == true then game.stat = "home" end
	if stat.dead == true then game.stat = "retry" end
	textBox.check(textBox,dt)
end

function love.update(dt)
	if game.stat == "inGame" or not timer.timeout(timer,dt) 
	then game.update(dt) 
	else menu.update(dt) end
	
	mouse.method.init(mouse)
end

function love.draw()
	love.graphics.setBackgroundColor(255,251,229,255)	
	if game.stat ~= "inGame" and  timer.time == 0 
	then menu.draw() 
	else game.draw() end

end
function love.mousepressed(x, y, button, istouch)
	mouse.leftClick = (button == 'l')  
	mouse.rightClick = (button == 'r') 
end
