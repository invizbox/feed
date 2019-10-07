#!/usr/bin/lua
-- Copyright 2016 InvizBox Ltd
-- https://www.invizbox.com/lic/license.txt
local uci = require("uci").cursor()

print([[Content-Type: text/html

<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="utf-8"/>
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
<meta http-equiv="Pragma" content="no-cache" />
<meta http-equiv="Expires" content="0" />]])

local wizard_complete = uci:load("wizard") and uci:get("wizard", "main", "complete") ~= "false"
if wizard_complete then
    print('<meta http-equiv="refresh" content="0; URL=/cgi-bin/luci" />')
else
    print('<meta http-equiv="refresh" content="0; URL=/cgi-bin/luci/wizard/wizard" />')
end

print('</head>'..
        '<body style="background-color: white">'..
        '<a style="color: black; font-family: arial, helvetica, sans-serif;" href="/cgi-bin/luci">'..
        'LuCI - Lua Configuration Interface</a>'..
        '</body>'..
        '</html>')
