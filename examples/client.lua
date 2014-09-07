package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;examples/?.lua"

local socket = require "clientsocket"
local bit32 = require "bit32"
local proto = require "proto"
local sproto = require "sproto"

local rpc = sproto.new(proto):rpc "package"

local fd = assert(socket.connect("127.0.0.1", 8888))

local function send_package(fd, pack)
	local size = #pack
	local package = string.char(bit32.extract(size,8,8)) ..
		string.char(bit32.extract(size,0,8))..
		pack

	socket.send(fd, package)
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
	local result
	result, last = unpack_package(last)
	if result then
		return result, last
	end
	local r = socket.recv(fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error "Server closed"
	end
	return unpack_package(last .. r)
end

local session = 0

local function send_request(name, args)
	session = session + 1
	local str = rpc:request(name, args, session)
	send_package(fd, str)
	print("Request:", session)
end

local last = ""

local function dispatch_package()
	while true do
		local v
		v, last = recv_package(last)
		if not v then
			break
		end

		local t, session, response = rpc:dispatch(v)
		assert(t == "RESPONSE" , "This example only support request , so here must be RESPONSE")
		print("response session", session)
		for k,v in pairs(response) do
			print(k,v)
		end
	end
end

send_request("handshake")
while true do
	dispatch_package()
	local cmd = socket.readstdin()
	if cmd then
		send_request("get", { what = cmd })
	else
		socket.usleep(100)
	end
end
