--[[ 
	Client FTP.
	FTP client library for Play Station Vita.
	
	Licensed by GNU General Public License v3.0
	
	Designed By:
	- DevDavisNunez (https://twitter.com/DevDavisNunez).
	
]]

function newFtpClient(ip, port)
	local obj = {
		-- Config Vars
		ip = ip or "ftp.gnu.org",
		port = port or 21,
		dport = (port or 21) + 1,
		user = "anonymous",
		pass = "",
		useTLS = false, -- This is disabled because no hand ssl sock in vita for now. :(
		ssl_type = false, -- In ssl type sock! :D xD
		timeout = 6 * 1000, -- 6s of timeout...
		retry_num = 2, -- Retry 2 times..
		
		-- Handle Vars
		crono = timer.new(), -- Timer for timeout...
		ctrl_port = nil, -- Port of ctrl 
		data_port = nil, -- Port of data
		response = "", -- Response raw from server.
		path = "/", -- The path in the server.. or cwd xD
	}

	function obj.init(obj) -- Create and connect to the server.
		if obj.ctrl_port then obj.ctrl_port:close() end -- if have previus connection, close and continue.
		print("Connect to %s:%d\n", obj.ip, obj.port)
		obj.ctrl_port = socket.connect(obj.ip, obj.port)
		obj.dport = obj.port + 1
		print("Connected, waiting Welcome Message\n")
	end
	
	function obj.term(obj) -- Close and destroy the conection.
		if obj.ctrl_port then obj.ctrl_port:close() end -- if have previus connection, close.
		obj.ctrl_port = nil
	end
	
	function obj.connect(obj, user, pass)
		obj:init()
		obj:recvCMD() -- Hello msg
		if obj:returnCode() != 220 then print("Error server is not responding...") obj:term() end
		if obj.useTLS then
			local res, result = obj:SendRecvCMD("AUTH","TLS")
			if res and obj:returnCode() <= 300 then
				obj.ssl_type = true
				print("Is Ssl required!..\n")
			else
				print("No accept TLS!, Try again with normal conn\n");
				obj:init()
				obj:recvCMD() -- Hello msg
			end
		end
		if obj:SendRecvCMD("USER",user) and obj:SendRecvCMD("PASS",pass) then
			if obj.ssl_type then
				obj:SendRecvCMD("PBSZ","0")
				obj:SendRecvCMD("PROT","P")
			end
			obj:cdir()
			return true
		end
		return false
	end
	
	function obj.sendCMD(obj, cmd, args)
		if not obj.ctrl_port then print("Error in sendCMD: Sock CTRL!\n"); return end
		
		local out = string.format("%s\r\n",cmd);
		
		if args and #args > 0 then out = string.format("%s %s\r\n",cmd, args); end
		
		if obj.ssl_type then -- SSL Socket
		else socket.send(obj.ctrl_port, out); -- Normal Socket
		end
		
		if cmd == "PASS" then out = string.format("%s %s\r\n",cmd, string.rep('*', 6)); end
		print("Client: %s", out);
	end
	
	function obj.recvCMD(obj, timeout)
		print("Server NATIVE:\n")
		obj.crono:reset()
		local buff, size = "", 0;
		while obj.crono:time() < (timeout or obj.timeout) do
			local data, len = socket.recv(obj.ctrl_port, 8192*3)
			if len > 0 then
				obj.crono:stop()
				print(data)
				buff = buff..data
				size = size + len
			elseif len == 0 then
				obj.crono:start()
			elseif len < 0 then
				print("Error in recvCMD: Sock CTRL!\n")
				break;
			end
			if buff:find("\r\n") then
				local tmp = buff / '\n'
				local complete = false
				for i=1, #tmp do
					local code, unk1 = string.match(tmp[i], "(%d+)(.+)");
					if unk1 and unk1:sub(1,1) != "-" then buff = tmp[i]; complete = true; break; end
					if tmp[i]:find("%d%d%d") and tmp[i]:sub(4,4) != "-" then buff = tmp[i]; complete = true; break; end
				end
				--print("The recv cmd is complete!\n")
				if complete then break; end
			end
		end
		if obj.crono:time() > (timeout or obj.timeout) then
			print("recvCMD timed out...\n");
			print("Server: %s\n", buff);
			return false, buff, size;
		end
		obj.response = buff;
		print("Server: %s\n", buff);
		return true, buff, size;
	end
	
	function obj.SendRecvCMD(obj, cmd, args, timeout)
		local success, buff, size, try = false, "", 0, 0;
		while not success do
			if try < obj.retry_num then
				obj:sendCMD(cmd, args);
				success, buff, size = obj:recvCMD(timeout);
				try += 1;
			else
				print("Error in SendRecvCMD: Retry is fail!...\n");
				break;
			end
		end
		return success, buff, size;
	end
	
	function obj.openDataPort(obj) -- Create and connect the data port to the server.
		if obj.data_port then obj.data_port:close() end -- if have previus connection, close and continue.
		print("DataPort Connect to %s:%d\n", obj.ip, obj.dport)
		obj.data_port = socket.connect(obj.ip, obj.dport)
		--print("Connected!\n")
	end
	
	function obj.sendRaw(obj, data, len)
		if not obj.data_port then print("Error in sendRaw: Sock DATA!\n"); return 0; end
		return socket.send(obj.data_port, data, len)
	end
	
	function obj.recvRaw(obj, len)
		if not obj.data_port then print("Error in recvRaw: Sock DATA!\n"); return "",0; end
		return socket.recv(obj.data_port, (len or 8192));
	end
	
	function obj.closeDataPort(obj)
		if obj.data_port then obj.data_port:close() end -- if have previus connection, close.
		obj.data_port = nil
	end
	
	function obj.goPasvMode()
		obj:SendRecvCMD("PASV")
		local vars = string.between(obj.response,'(',')') / ','; -- check the cause of error in match 'string.match(vars, "((.+),(.+),(.+),(.+),(.+),(.+))")'
		obj.dport = tonumber(vars[5] << 8) + tonumber(vars[6]); -- Convert port 2 bytes to short or int16 xD
	end
	
	function obj.returnCode(obj)
		local code, msg = string.match(obj.response,"(%d+)(.+)");
		return tonumber(code or 0), msg;
	end
	
	function obj.cdir(obj, path)
		if path then
			obj:SendRecvCMD("CWD", obj.path .. path .. "/") -- Set new root
		end
		-- Check the new root.
		if obj:SendRecvCMD("PWD","") then
			local code, msg = obj:returnCode();
			if code == 257 then
				local root = string.match(msg,'"(.+)"');
				if root:sub(-1, -1) != '/' then root += '/' end
				obj.path = root
			end
		end
		return obj.path;
	end
	
	function obj.upload(obj, path)
		obj:SendRecvCMD("TYPE", "I")
		obj:sendCMD("STOR", path)
		obj:goPasvMode()
		obj:openDataPort()
		print("Upload %s\n", path)
		local fp = io.open(path, "rb")
		local size = files.size(path)
		-- obj.crono:reset() -- TO-DO add timeout! :(
		local written = 0
		while written < size do
			local len = 1024
			if len > size - written then
				len = size - written
			end
			obj:sendRaw(fp:read(len), len)
			written += len
			onFtpPutFile(size, written)
			os.delay(16)
		end
		obj:closeDataPort()
		io.close(fp)
		obj:recvCMD()
	end
	
	function obj.download(obj, path, root)
		if obj:SendRecvCMD("SIZE", path) then
			local code, msg = obj:returnCode();
			local size,bytes = tonumber(msg), 0;
			if code == 213 then
				obj:SendRecvCMD("TYPE", "I")
				obj:goPasvMode()
				obj:openDataPort()
				obj:sendCMD("RETR", path)
				obj:recvCMD()
				print("Download %s\n", path)
				local fp = io.open(string.format("%s%s",(root or ""), path), "wb")
				obj.crono:reset()
				while (bytes < size) or (obj.crono:time() < 1000) do
					local data, len = obj:recvRaw(8192* 3)
					if len > 0 then
						obj.crono:stop()
						fp:write(data)
						bytes += len
						onFtpGetFile(size, bytes)
					elseif len == 0 then
						obj.crono:start()
					elseif len < 0 then
						print("Error in Download: Sock Data!\n")
						break;
					end
				end
				io.close(fp)
				obj:closeDataPort()
				obj:recvCMD()
			end
		end
	end
	
	function obj.list(obj, path)
		if path then
			-- TO-DO: add cwd
		end
		obj:SendRecvCMD("TYPE", "I")
		obj:goPasvMode()
		obj:openDataPort()
		obj:sendCMD("LIST") -- "*.php" return by ext
		obj:recvCMD() -- Recv the msg of data port success!
		if not obj:recvCMD() then return {} end --Recv the msg of list cmd.
		local code, unk2 = string.match(obj.response,"(%d+)(.+)");
		local num_entrys, unk3 = string.match(unk2,"(%d+)(.+)");
		num_entrys = tonumber(num_entrys) or 999999
		local mask_month = {Jan=1, Feb=2, Mar=3, Apr=4, May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec = 12}
		local list = {}
		local buff, size = "", 0;
		print("List:\n")
		obj.crono:reset()
		while (#list < (num_entrys)) or (obj.crono:time() < (500)) do --obj.timeout
			local data, len = obj:recvRaw(8192* 3)
			if len > 0 then
				obj.crono:stop()
				print(data)
				buff = buff..data
				size = size + len
			elseif len == 0 then
				obj.crono:start()
			elseif len < 0 then
				print("Error in LIST: Sock Data!\n")
				break;
			end
			if buff:find("\r\n") then
				buff = buff / '\r\n'
				for i=1, #buff-1 do
					if #buff[i] < 10 then continue end
					local attr, unk1, user1, user2, size, month, day, year, name  = string.match(
						buff[i], "(.+) (%d+) (.+) (.+) (%d+) (.+) (.+) (.+) (.+)")
					if string.match(year, "(%d+):(%d+)") then
						year = "2017"
					end
					if name:sub(-1,-1) == ' ' then name = name:sub(1, #name - 1) end -- trim the last space! :(
					--if name:sub(1,1) == '.' then continue end -- Skip the "." path
					table.insert(
						list,
						{
							name = name,
							ext = files.ext(name),
							mtime = string.format("%02d/%02d/%s",tonumber(trim(day)) or -10,mask_month[trim(month)] or -50,trim(year)),
							size = size,
							fsize = files.sizeformat(size),
							directory = (string.find(attr,"d") != nil), -- 'l' to link type :P
						}
					)
				end
				buff = buff[#buff]
			end
		end
		obj:closeDataPort()
		return list;
	end
	
	function obj.delete(obj, path)
		obj:SendRecvCMD("DELE", path)
	end
	
	function obj.cwd(obj)
		return obj.path;
	end
	
	return obj;
end