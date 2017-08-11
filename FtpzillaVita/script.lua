--[[ 
	FTPzilla Vita.
	The first FTP client for Play Station Vita.
	
	Licensed by GNU General Public License v3.0
	
	Designed By:
	- DevDavisNunez (https://twitter.com/DevDavisNunez).
	
	Version 0.9 at 12:00 am - 10/08/17
	
]]

__RELEASE = true -- Uncomment in release
__DEBUGIP, __DEBUGPORT = "192.168.1.79", 18194

color.loadpalette()
dofile("lib/debug.lua")
dofile("git/updater.lua")
dofile("utils.lua")
dofile("lib/wave.lua")
dofile("lib/explorer.lua")
dofile("lib/ftpclient.lua")

-- ## Resources ##
local wave = newWave()
wave:begin("res/wave.png") --wave:alfa(100)
local mimes = image.load("res/icons.png",16,16)
local back = image.load("sce_sys/livearea/contents/bg0.png")

local icons = {
	pbp=2,prx=2,
	png=3,gif=3,jpg=3,bmp=3,
	mp3=4,s3m=4,wav=4,at3=4,
	rar=5,zip=5,vpk=5,
	cso=6,iso=6,dax=6
}

function onFtpGetFile(size,written,speed)
	if back then back:blit(0,0) end
	screen.print(10,10,"Downloading...")
	screen.print(10,30,"Size: "..tostring(size).." Written: "..tostring(written).." Speed: "..tostring(speed).."Kb/s")
	screen.print(10,50,"Porcent: "..math.floor((written*100)/size).."%")
	draw.fillrect(0,520,((written*960)/size),24,color.new(0,255,0))
	screen.flip()
	buttons.read()
	if buttons.circle then	return 0 end --Cancel or Abort
	return 1;
end

function onFtpPutFile(size,written,speed)
	if back then back:blit(0,0) end
	screen.print(10,10,"Uploading...")
	screen.print(10,30,"Size: "..tostring(size).." Written: "..tostring(written).." Speed: "..tostring(speed).."Kb/s")
	screen.print(10,50,"Porcent: "..math.floor((written*100)/size).."%")
	draw.fillrect(0,520,((written*960)/size),24,color.new(0,255,0))
	screen.flip()
	buttons.read()
	if buttons.circle then	return 0 end --Cancel or Abort
	return 1;
end

print("Init client FTP!\n")
print("FTPzilla Vita Client v0.9.0\n")
print("Client IP " .. wlan.getip().."\n")
local cfg = {
	server = ini.read("config.ini", "server", ""),
	port = ini.read("config.ini", "port", "21"),
	user = ini.read("config.ini", "user", "anonymous"),
	pass = ini.read("config.ini", "pass", ""),
	mask = {
		"server", "port", "user", "pass"
	}
}

local opt = 1;
while true do -- Configurator! :D
	buttons.read()
	if back then back:blit(0,0) end
	wave:blit(4)
	draw.fillrect(240, 136, 480, 272, color.shadow)
	screen.print(480, 145, "- FTPzilla Config -",1, color.white, color.black, __ACENTER)
	local y = 185
	for i=1, 5 do
		local cc, bb = color.white, color.shine
		if opt == i then cc,bb = color.green, color.blue:a(100) end
		if i < 5 then
			screen.print(250+100, y, string.format("%s:",cfg.mask[i]), 1, color.white, 0x0, __ARIGHT)
			draw.fillrect(250+120, y, 300, 20, bb)
			screen.print(250+125, y, cfg[cfg.mask[i]] ,1, color.white, 0x0)
		else
			draw.fillrect(480-75,y+20, 150, 20, bb)
			screen.print(480, y+20, "Continue",1, color.white, 0x0, __ACENTER)
		end
		y += 25
	end
	screen.flip()
	if buttons.up then opt -= 1
	elseif buttons.down then opt += 1
	end
	if opt < 1 then opt = 5 elseif opt > 5 then opt = 1 end
	if buttons.cross then
		if opt == 5 then break
		else
			local type = 1
			if cfg.mask[opt] == "port" then type = 2 end
			local res = osk.init(cfg.mask[opt], cfg[cfg.mask[opt]], type)
			if res then
				cfg[cfg.mask[opt]] = res
				ini.write("config.ini", cfg.mask[opt], res)
			end
		end
	end
end
local cftp = newFtpClient(cfg.server, tonumber(cfg.port) or 21);
cftp:connect(cfg.user, cfg.pass)
--cftp:cdir("public_html")
local list = cftp:list()
local scroll = newScroll(list, 20)

while true do
	buttons.read()
	if back then back:blit(0,0) end
	wave:blit(4)
	draw.fillrect(0,0,960,25,color.shine)
	screen.print(5,5,"ftp:/"..cftp:cwd(),1, color.white)
	screen.print(950,5,"Count: "..#list,1, color.white, 0x0, __ARIGHT)
	y = 35
	for i=scroll.ini, scroll.lim do
		
		if not list[i].directory then
			if icons[list[i].ext] then mimes:blitsprite(5, y, icons[list[i].ext]) -- mime type
			else mimes:blitsprite(5, y, 0) end -- file unk
		else
			mimes:blitsprite(5, y, 1) -- folder xD
		end
		
		local cc = color.white
		if list[i].directory then cc = color.yellow end
		if i==scroll.sel then cc = color.green end
		screen.print(25, y, list[i].name, 1, cc)
		if list[i].name != "." and list[i].name != ".." --[[and list[i].directory]] then
			local text = "<DIR>"
			if not list[i].directory then text = tostring(list[i].fsize) end
			screen.print(950, y, text, 1, cc,0x0, __ARIGHT)
			screen.print(800, y, list[i].mtime--[["<DIR>"]], 1, cc,0x0, __ARIGHT)
		end
		y += 20
	end
	screen.flip()
	
	if buttons.up or buttons.analogly < -60 then
		scroll:up()
	elseif buttons.down or buttons.analogly > 60 then
		scroll:down()
	end
	
	if buttons.circle then -- TO-DO: Add back!

	elseif buttons.cross then
		if list[scroll.sel].directory then
			cftp:cdir(list[scroll.sel].name)
			list = cftp:list()
			scroll:set(list, 20)
		else
			cftp:download(list[scroll.sel].name)
		end
	elseif buttons.triangle then
		--cftp:upload(path)
	elseif buttons.left then
	elseif buttons.right then
	elseif buttons.select then
	end
end