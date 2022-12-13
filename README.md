# Godot 4 Ocean Shader
An early work in progress ocean shader for Godot 4 base on Jerry Tessendorf's
FFT method for generating the waves, using compute shaders to generate the
displacement map.

The GLSL shaders that generates the displacement map were ported into Godot 4
from [this project](https://github.com/achalpandeyy/OceanFFT). The underlying
math is identical, but some things like binding points and how uniforms were
accessed had to be changed to work in Godots compute shader API.

Press the `/~ key while running the example scene to toggle the debug texture
views for the displacement and normal maps.

![Screenshot_20221202_025727](https://user-images.githubusercontent.com/118585625/205235274-9a48e867-f7cf-4aeb-9114-f3d78745cd31.png)

## Todo List
- Improve visual rendering
  - Foam
  - Splash particles
  - Light interactions (transparency, refractions)
- Improve quad tree LOD transitions, and lower detail but faster visual shader for lower LOD quads
- Improve buoyancy system for large objects
- Cascading FFTs
- Multiplayer synchronization? [This reference](https://developer.download.nvidia.com/assets/gameworks/downloads/regular/events/cgdc15/CGDC2015_ocean_simulation_en.pdf) may be helpful for this.

![Screenshot_20221202_030052](https://user-images.githubusercontent.com/118585625/205235329-aecbe521-3a46-4d29-985c-84bc204ccc6c.png)

## References
### Wave Generation Theory
- [Jerry Tessendorf - Simulating Ocean Water](https://people.computing.clemson.edu/~jtessen/reports/papers_files/coursenotes2004.pdf)
- [Fynn-Jorin Flügge - Realtime GPGPU FFT Ocean Water Simulation](https://tore.tuhh.de/bitstream/11420/1439/1/GPGPU_FFT_Ocean_Simulation.pdf)
- [Thomas Gamper - Ocean Surface Generation and Rendering](https://www.cg.tuwien.ac.at/research/publications/2018/GAMPER-2018-OSG/GAMPER-2018-OSG-thesis.pdf)

### Water Implementation Examples
These are not exclusively limited to ocean wave implementations, and may
include other types of water simulations if they include visual rendering
techniques that are of value to reference.

- The implementation behind the wave height generation: [achalpandeyy/OceanFFT](https://github.com/achalpandeyy/OceanFFT)
- [Platinguin/Godot-Water-Shader-Prototype](https://github.com/Platinguin/Godot-Water-Shader-Prototype/)

### AAA-Game Implementation Examples
These generally don't give much in the way of code examples, but do give
a higher level overview of how the whole thing comes together.

- [Assassin’s Creed III: The tech behind (or beneath) the action](https://www.fxguide.com/fxfeatured/assassins-creed-iii-the-tech-behind-or-beneath-the-action/)
- [The technical art of Sea of Thieves](https://dl.acm.org/doi/10.1145/3214745.3214820)
- [Ocean simulation and rendering in War Thunder](https://developer.download.nvidia.com/assets/gameworks/downloads/regular/events/cgdc15/CGDC2015_ocean_simulation_en.pdf)

### LOD Theory/Implementation
- [Filip Struger - Continuous Distance-Dependent Level of Detail for Rendering Heightmaps (CDLOD)](https://github.com/fstrugar/CDLOD/blob/master/cdlod_paper_latest.pdf)
- ~~[Claes Johanson - Real-time water rendering Introducing the projected grid concept](https://fileadmin.cs.lth.se/graphics/theses/projects/projgrid/projgrid-lq.pdf)~~ The projected grid method was not used in this project.

### Miscellaneous
- [ARM Software - Using the Jacobian for modelling turbulent effects at wave crests](https://arm-software.github.io/opengl-es-sdk-for-android/ocean_f_f_t.html#oceanJacobian)
- [Jump Trajectory - Ocean waves simulation with Fast Fourier transform](https://www.youtube.com/watch?v=kGEqaX4Y4bQ)
