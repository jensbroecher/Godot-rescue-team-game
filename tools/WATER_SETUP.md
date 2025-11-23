# Tiled Animated Water Shader Setup

This guide shows how to use the water animation shader with your extracted frames.

## Step 1: Generate the Atlas

1. Open Godot and navigate to your project.
2. Create a new scene with a `Node` at the root.
3. Attach the script `res://tools/water_atlas_generator.gd` to the root node.
4. Run the scene (press **F5** or click **Play**).
5. Check the **Output** console—it will say:
   ```
   Loaded 17 frames
   Atlas saved to res://water_atlas.png
   Metadata saved to res://water_atlas_meta.tres
   ```
6. Close the scene and **delete the generator node** (or the entire scene).
7. Verify `res://water_atlas.png` exists in the file system (it may need a refresh: **Ctrl+R**).

## Step 2: Create a Water Surface

### Option A: Using a Sprite2D (Simplest)

1. Create a new scene with `Sprite2D` as the root.
2. Rename it to `Water`.
3. In the Inspector, set **Texture** to `res://water_atlas.png`.
4. Scale the sprite to cover your water area (adjust **Scale** on the Transform).

### Option B: Using a MeshInstance2D (More Control)

1. Create a new scene with `MeshInstance2D` as the root.
2. Rename it to `Water`.
3. In the Inspector, set **Mesh** to `QuadMesh`.
4. Adjust **QuadMesh** size to your desired water dimensions.
5. (Optional) You can tile the mesh multiple times using the **Offset** in the material.

## Step 3: Create and Assign the Shader Material

1. With your water sprite/mesh selected, create a **CanvasItem** material:
   - In the Inspector, find **Material** (under CanvasItem).
   - Click the empty slot and select **New CanvasItemMaterial**.
2. Click on the material to open it.
3. Scroll down and find **Shader**.
4. Click the empty slot and select **New Shader**.
5. In the new shader editor, delete the default code and paste the contents of `res://shaders/water.shader`.
6. Close the shader editor.

### Alternative: Direct Material Assignment

If you prefer, create a `res://materials/water.tres` material resource:
1. In the FileSystem, right-click and select **New Resource** → **ShaderMaterial**.
2. In the Inspector, set **Shader** to `res://shaders/water.shader`.
3. Save as `res://materials/water.tres`.
4. On your water sprite/mesh, assign this material to **Material**.

## Step 4: Configure Shader Parameters

With the shader material selected, you'll see these uniforms in the Inspector:

- **Atlas**: Path to `res://water_atlas.png` (set this automatically if using a Sprite2D).
- **Frame Count**: Number of frames (default: 17 for your animation).
- **Cols**: Columns in the atlas grid (default: 4).
- **Rows**: Rows in the atlas grid (default: 5 = ceil(17/4)).
- **Animation Speed**: Speed multiplier for frame cycling (default: 1.0; increase for faster animation).
- **Tile Scale**: How many times to tile the animation across the surface (default: 2; increase for smaller, more frequent tiles).

## Example Configuration

For a typical water effect:
```
Animation Speed: 1.5
Tile Scale: 3
Frame Count: 17
```

This tiles the water 3× across the quad and cycles through all 17 frames at 1.5× normal speed.

## Adjusting Tile Appearance

- **Tile Scale = 1**: Full animation frame displayed once (may show stretching at edges).
- **Tile Scale = 2–4**: Animation repeats multiple times, creating a seamless tiled effect.
- **Tile Scale = 8+**: Very small tiles; good for detailed, fine water ripples.

## Tweaking Animation Speed

- **Animation Speed = 0.5**: Slow, relaxed waves.
- **Animation Speed = 1.0**: Default speed (each frame plays for ~1/17 second).
- **Animation Speed = 2.0–3.0**: Fast, choppy water.

## Troubleshooting

### Black Water
- Ensure `res://water_atlas.png` exists and is set in the material's **Atlas** uniform.
- Check that the atlas was generated (see Step 1).

### Frames Not Animating
- Verify **Frame Count** matches your actual frame count (17 in your case).
- Increase **Animation Speed** if the animation is too slow to notice.

### Distorted Texture
- This shader tiles without distortion by design. If you see stretching, verify:
  - **Cols** and **Rows** are correct (4 and 5 for your atlas).
  - The original frames are all the same size.

### Seams Between Tiles
- Ensure your original frame images have matching edge colors or use a small Tile Scale (2–3).
- Alternatively, export your frames with built-in padding/smoothing.

## Performance

This shader is lightweight and runs in 2D (canvas_item). It's suitable for mobile and web targets.
If using many water surfaces, consider:
- Using fewer, larger water quads instead of many small ones.
- Reducing **Tile Scale** if performance is an issue.

## Next Steps

- Add parallax scrolling by offsetting the **Atlas** uniform over time.
- Blend multiple water layers with different **Animation Speed** values for complex effects.
- Combine with vertex displacement for 3D-like wave deformation (advanced).
