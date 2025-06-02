This is an MCP server for Godot written in Swift.  This is
over-the-wire compatible with the https://github.com/ee0pdt/Godot-MCP
implementation, so you can use this MCP server while using the Godot
supporting infrastructure from the addons directory on that
implementation.

The reason for this separate implementation is that on the iPad with
Xogot, we wont be able to run an out of process MCP server, so this
version contains a pluggable provider infrastructure.

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

# Building

Type `swift build` and this will produce a debug build under 
the `.build` directory: `.build/debug/godot-mcp-server-cli`

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

This currently is hardcoded to talk to a Godot running on my local system
at 10.10.11.195, you will need to change that address to point to your own
host (typically 127.0.0.1), and you will need to run the Godot-MCP addon
in your project (from above).
