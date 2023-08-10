# Prop Painter
Prop Painter is an addon for Godot 4 (developed and tested on Godot 4.1.1) to help you organize and place assets. Prop Painter supports PackedScene files (.tscn, .glb, .blend, .fbx, .dae). Support for .res files is unreliable.

Open the settings.tres file at least once, or settings won't be saved.

## How It Works
Add tabs to create libraries into which you drag and drop your assets from the FileSystem. Prop Painter will then generate previews. 
![pp_drag_n_drop](https://github.com/gildedhipbone/prop_painter/assets/36510916/94735f11-0575-42ab-9082-dcf1d6808e97)

You can export and import libraries, collections of ResourceUIDs, as .json.
![pp_import_library](https://github.com/gildedhipbone/prop_painter/assets/36510916/83c2748f-d51b-4094-adb7-a33861c5860e)

Choose a parent node (must be or extend Node3D) and select the asset(s) that you want to place. If you've selected multiple assets Prop Painter will cycle randomly between them. Left-click (and drag) to place. Right-click to erase.
![pp_parent_place](https://github.com/gildedhipbone/prop_painter/assets/36510916/fefecd36-aaa8-4737-887c-fcabcb329898)
![pp_select_multiple](https://github.com/gildedhipbone/prop_painter/assets/36510916/0ecff392-7439-4fb4-a8b2-429aa542976e)

You can change the base scale of an asset, as well as introduce random rotation and scale. You can also make the asset align to the surface normal.
![pp_select_properties](https://github.com/gildedhipbone/prop_painter/assets/36510916/82f5e75b-1331-44af-ba82-f49f7bc53064)
* Terrain created with Terrain3D: https://github.com/outobugi/Terrain3D
* Assets are from the Ultimate Nature Pack by Quaternius: https://quaternius.com/packs/ultimatenature.html

## Keep in Mind
* Prop Painter uses ResourceUIDs to keep track of assets, which *should* mean that you can move the files around the FileSystem without having to re-add them to the palette. However, I suggest that you disable the plugin before moving anything around and then reload the project.

 ## To-Do
* Undo/Redo!
* Drag & drop from the palette into the scene
* Grid & snap support
* Drag & drop onto tabs
* Move/copy assets between tabs
* Option to automatically populate the palette based on folder structure
 
