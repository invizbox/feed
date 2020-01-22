#!/usr/bin/lua
-- Copyright 2017 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- this file includes an implementation to fake connectivity when it comes to captive portal checking

local uri = os.getenv("REQUEST_URI")
local user_agent = os.getenv("HTTP_USER_AGENT")

if user_agent and string.sub(user_agent, 1, 21) == "CaptiveNetworkSupport" then -- IOS
    print("Status: 200 OK")
    print("Content-Type: text/html")
    print("Content-Length: 68")
    print("Cache-Control: max-age=300")
    print("")
    io.write("<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>")
elseif uri and uri == "/generate_204" or uri == "/gen_204" then -- Android
    print("Status: 204 No Content")
    print("")
elseif uri and uri == "/ncsi.txt" then -- Microsoft
    print("Status: 200 OK")
    print("Content-Type: text/plain")
    print("Content-Length: 14")
    print("Cache-Control: max-age=30, must-revalidate")
    print("")
    io.write("Microsoft NCSI")
elseif uri and uri == "/connecttest.txt" then -- Microsoft
    print("Status: 200 OK")
    print("Content-Type: text/plain")
    print("Content-Length: 22")
    print("Content-MD5: BMP8SohYjuR9M9BmkgrEEA==")
    print("")
    io.write("Microsoft Connect Test")
elseif uri and uri == "/success.txt" then --Mozilla
    print("Status: 200 OK")
    print("Content-Type: text/plain")
    print("Content-Length: 8")
    print("Cache-Control: no-cache, no-store, must-revalidate")
    print("")
    print("success")
else -- otherwise redirect to main page
    print("Status: 302 Found")
    print("Initial: "..uri)
    print("Location: /")
    print("")
end
