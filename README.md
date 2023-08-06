# Prop Painter
Prop Painter is an addon for Godot 4 (developed and tested on Godot 4.1.1) to help you organize and place assets. At the moment Prop Painter supports PackedScene files (including .glb and .fbx) and .res files. Unfortunately, preview images are currently not generated for converted PackedScene files (e.g. .glb).

## How It Works
Add tabs to create libraries into which you drag and drop relevant assets from the FileSystem. Prop Painter will generate a preview for each asset. You can export and import libraries as .json, which should make updates relatively painless.
 gif
Choose a parent node (must be or extend Node3D) and select the asset(s) that you want to place. If you've selected multiple assets Prop Painter will cycle randomly between them.
 gif
You can change the base scale of an asset, as well as introduce random rotation and scale. You can also make the asset align to the surface normal.
 gif

 ## Possible Future Features
* Drag and drop from the palette
* Support more formats
* Grid & snap support
* Drag and drop on tabs
* Move/copy props from one tab to another
* Option to automatically populate tabs and props based on folder structure
 
