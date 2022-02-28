#!/usr/bin/lua
-- Copyright 2018 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
-- this file includes an implementation to fake connectivity when it comes to captive portal checking

-- luacheck: globals lighty
local uri = lighty.env["uri.path"]
local user_agent = lighty.request["User-Agent"] or ""
if string.sub(user_agent, 1, 21) == "CaptiveNetworkSupport" then -- IOS
    --print("redirecting IOS captive request")
    lighty.header["Status"] = "200 OK"
    lighty.header["Content-Type"] = "text/html"
    lighty.header["Content-Length"] = "68"
    lighty.header["Cache-Control"] = "max-age=300"
    lighty.content = {"<HTML><HEAD><TITLE>Success</TITLE></HEAD><BODY>Success</BODY></HTML>"}
    return 200
elseif uri == "/generate_204" or uri == "/gen_204" then -- Android
    --print("redirecting Android captive request")
    lighty.header["Status"] = "204 No Content"
    return 204
elseif uri == "/ncsi.txt" then -- Microsoft
    --print("redirecting Microsoft captive request")
    lighty.header["Status"] = "200 OK"
    lighty.header["Content-Type"] = "text/plain"
    lighty.header["Content-Length"] = "14"
    lighty.header["Cache-Control"] = "max-age=30, must-revalidate"
    lighty.content = {"Microsoft NCSI"}
    return 200
elseif uri == "/connecttest.txt" then -- Microsoft
    --print("redirecting Microsoft captive request")
    lighty.header["Status"] = "200 OK"
    lighty.header["Content-Type"] = "text/plain"
    lighty.header["Content-Length"] = "22"
    lighty.header["Content-MD5"] = "BMP8SohYjuR9M9BmkgrEEA=="
    lighty.content = {"Microsoft Connect Test"}
    return 200
elseif uri=="/success.txt" then --Mozilla
    --print("redirecting Mozilla captive request")
    lighty.header["Status"] = "200 OK"
    lighty.header["Content-Type"] = "text/plain"
    lighty.header["Content-Length"] = "8"
    lighty.header["Cache-Control"] = "no-cache, no-store, must-revalidate"
    lighty.content = {"success\n"}
    return 200
else
    --print("redirecting to captive page")
    lighty.header["Location"] = "http://inviz.box/captive.html"
    return 302
end
