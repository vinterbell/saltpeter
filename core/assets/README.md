# assets module
A module for loading and managing various types of assets like scenegraphs (gltf), images, and eventually audio and other types.

## Notes
- Completely independent of graphics or gpu modules, just loads data into cpu memory
- Uses core/math/linalg for math structures
- Has a c dependency on stbi for image loading
- Gltf loader has an optional glb data parameter to load binary glb files. If this is not present then it is a gltf file, and the bin will need to be loaded separately.
