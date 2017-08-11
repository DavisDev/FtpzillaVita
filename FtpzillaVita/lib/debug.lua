local zock = nil;

if not __RELEASE then
	zock = socket.connect(__DEBUGIP, __DEBUGPORT)
end

function print(...)
	if zock then zock:send(string.format(...)) end
end

