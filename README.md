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