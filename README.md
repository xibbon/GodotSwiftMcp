This is an MCP server for Godot written in Swift.  This is
over-the-wire compatible with the https://github.com/ee0pdt/Godot-MCP
implementation, so you can use this MCP server while using the Godot
supporting infrastructure from the addons directory on that
implementation.

The reason for this separate implementation is that on the iPad with
Xogot, we wont be able to run an out of process MCP server, so this
version contains a pluggable provider infrastructure, but as a bonus,
this also works with desktop Godot, and produces a self-contained MCP
server.


# Using GodotSwiftMcp

You will need to do three things:

* Compile the server using Swift
* Add the godot_mcp extension to your Godot project
* Tell your Chat app how to use the MCP server


## Building The GodotSwiftpMcp server 

You will need the Swift toolchain installed, once you do, type `swift
build` and this will produce a debug build under the `.build`
directory: `.build/debug/godot-mcp-server-cli`.

This command acts as the bridge between your chat client and Godot.

## Add the `godot_mcp` extension to your Godot project

For Godot to be able to field requests, you will need to add to your
project the `godot_mcp` project.   

If you have not installed that addon, just copy the contents of the
'addons/godot_mcp' directory into your Godot project, enable the addon
in Godot, and when the tab at the bottom of the screen appears, tap
"Start Server".   

## Configure your Chat CLient

Once you have this, you can configure your chat client to talk to it,
for example on my system, using Claude desktop, I go to
Settings->Developer, then "Edit Config" and I add this:

```
{
  "mcpServers": {
    "godot": {
      "command": "/Users/miguel/bin/godot-mcp-server-cli",
      "args": [
      ]
    }
  }
}
```

And reload my Claude.  After this, you can start requesting operations
from it.

# Developing

You can build this project, and then you can test against it using the 
MCP inspector, like this:

```
bash$ npx @modelcontextprotocol/inspector
```

Then connect to the HTTP address the inspector gives you, and make sure that
you configure it as follows:

1. Transport Type: STDIO
2. Command: path to the compiled binary after  (in my case: /Users/miguel/cvs/GodotSwiftMcp/.build/debug/godot-mcp-server-cli)

Then you can start it, and you can inspect the various methods you have.

# Internals

To test this implementation, I implemented the
GodotLocalSocketProvider, which uses WebSockets to communicate with
Godot.

In Xogot, this is replaced with an in-process version that talks
directly with Godot via SwiftGodot.

In addition to the baseline Godot-MCP, I also implemented the
additional features from the [pull request
#9](https://github.com/ee0pdt/Godot-MCP/pull/9)

Generally, this should work as a drop-in replacement for the MCP
server written in Node.


