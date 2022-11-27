# Godot 4 Ocean Shader
An early work in progress ocean shader for Godot 4 base on Jerry Tessendorf's
FFT method for generating the waves, using compute shaders to generate the
displacement and normal maps.

![image](https://user-images.githubusercontent.com/118585625/202946339-b6fd51ac-e242-4c2b-b645-ba96b89f352a.png)

The GLSL shaders that generate the displacement and normal maps were ported into
Godot 4 from [this project](https://github.com/achalpandeyy/OceanFFT). The
underlying math is identical, but some things like binding points and how
uniforms were accessed had to be changed to work in Godots compute shader API.

On my laptop with a dual core Intel i3, 4GB RAM, and Intel HD 4400 integrated
GPU, the example scene gets ~35fps when updating the FFT each frame.

Press the `/~ key while running the example scene to toggle the debug texture
views for the displacement and normal maps.

![image](https://user-images.githubusercontent.com/118585625/202946456-cb15ffcd-fe53-4d58-ba8c-a0fb1bb73b00.png)

## Todo List
- Improve visual rendering
  - Foam
  - Splash particles
  - Light interactions (reflections, refractions, sub surface scattering)
- Cascading FFTs
- Buoyancy physics
- Expand the current "static grid" mesh method to allow use in open world games. Possible options being considered:
  - [Continuous Distance-Dependent Level of Detail (CDLOD)](https://github.com/fstrugar/CDLOD/blob/master/cdlod_paper_latest.pdf)
  - [Projected Grid](https://fileadmin.cs.lth.se/graphics/theses/projects/projgrid/projgrid-lq.pdf)
- Multiplayer synchronization? [This reference](https://developer.download.nvidia.com/assets/gameworks/downloads/regular/events/cgdc15/CGDC2015_ocean_simulation_en.pdf) may be helpful for this.

## References
- The theory behind the wave generation: [Jerry Tessendorf - Simulating Ocean Water](https://people.computing.clemson.edu/~jtessen/reports/papers_files/coursenotes2004.pdf)
- The implementation behind the wave height generation: [achalpandeyy/OceanFFT](https://github.com/achalpandeyy/OceanFFT)
- [Platinguin/Godot-Water-Shader-Prototype](https://github.com/Platinguin/Godot-Water-Shader-Prototype/)
- [Assassin’s Creed III: The tech behind (or beneath) the action](https://www.fxguide.com/fxfeatured/assassins-creed-iii-the-tech-behind-or-beneath-the-action/)
- [The technical art of Sea of Thieves](https://dl.acm.org/doi/10.1145/3214745.3214820)
- [Ocean simulation and rendering in War Thunder](https://developer.download.nvidia.com/assets/gameworks/downloads/regular/events/cgdc15/CGDC2015_ocean_simulation_en.pdf)
- [Claes Johanson - Real-time water rendering Introducing the projected grid concept](https://fileadmin.cs.lth.se/graphics/theses/projects/projgrid/projgrid-lq.pdf)
- [Continuous Distance-Dependent Level of Detail for Rendering Heightmaps (CDLOD)](https://github.com/fstrugar/CDLOD/blob/master/cdlod_paper_latest.pdf)
- [Jump Trajectory - Ocean waves simulation with Fast Fourier transform](https://www.youtube.com/watch?v=kGEqaX4Y4bQ)
