# Godot 4 Ocean Shader
An early work in progress ocean shader for Godot 4 base on Jerry Tessendorf's
FFT method for generating the waves, using compute shaders to generate the
displacement map.

The GLSL shaders that generates the displacement map were ported into Godot 4
from [this project](https://github.com/achalpandeyy/OceanFFT). The underlying
math is identical, but some things like binding points and how uniforms were
accessed had to be changed to work in Godots compute shader API.

|  Button  |  Action  |
| --- | --- |
|  `/~  |  Toggle menu/free cam modes|
|  Mouse Motion  |  Free cam look|
|  W  |  Free cam forwards (locked to horizontal plane)|
|  S  |  Free cam backwards (locked to horizontal plane)|
|  A  |  Free cam strafe left (locked to horizontal plane)|
|  D  |  Free cam strafe right (locked to horizontal plane)|
|  Space  |  Free cam up (locked to vertical axis)|
|  Ctrl  |  Free cam down (locked to vertical axis)|
|  Shift  |  Free cam sprint/move faster|

![Ocean](https://user-images.githubusercontent.com/118585625/212502974-757f7f29-684a-4821-a280-bf406ce1ffe6.png)

## Todo List
- Refactor project as Godot addon
- Improve visual rendering
  - Foam
  - Splash particles
  - Improve light interactions (transparency, reflections refractions)
- Improve quad tree LOD transitions, and lower detail but faster visual shader for lower LOD quads
- Improve buoyancy system
- Beach/cliff/rocks interactions
- Wave collision interactions (boat wakes, splashes, etc.)
- Multiplayer synchronization? [This reference](https://developer.download.nvidia.com/assets/gameworks/downloads/regular/events/cgdc15/CGDC2015_ocean_simulation_en.pdf) may be helpful for this.

![OceanCurve](https://user-images.githubusercontent.com/118585625/212503106-9f6eb378-9d6d-4d5e-8fbf-f058a857088b.png)

## References
### Wave Generation Theory
- [Jerry Tessendorf - Simulating Ocean Water](https://people.computing.clemson.edu/~jtessen/reports/papers_files/coursenotes2004.pdf)
- [Fynn-Jorin Flügge - Realtime GPGPU FFT Ocean Water Simulation](https://tore.tuhh.de/bitstream/11420/1439/1/GPGPU_FFT_Ocean_Simulation.pdf)
- [Thomas Gamper - Ocean Surface Generation and Rendering](https://www.cg.tuwien.ac.at/research/publications/2018/GAMPER-2018-OSG/GAMPER-2018-OSG-thesis.pdf)

### Wave Collision Interaction
- [Jerry Tessendorf - eWave: Using an Exponential Solver on the iWave Problem](https://people.computing.clemson.edu/~jtessen/reports/papers_files/ewavealgorithm.pdf)
- [Jerry Tessendorf - Simulation of Interactive Surface Waves](https://people.computing.clemson.edu/~jtessen/reports/papers_files/SimInterSurfWaves.pdf)
- [Stefan Jeschke, Tomáš Skřivan, Matthias Müller-fischer, Nuttapong Chentanez, Miles Macklin, Chris Wojtan - Water Surface Wavelets](https://dl.acm.org/doi/pdf/10.1145/3197517.3201336)

### Water Implementation Examples
These are not exclusively limited to ocean wave implementations, and may
include other types of water simulations if they include visual rendering
techniques that are of value to reference.

- The implementation behind the wave height generation: [achalpandeyy/OceanFFT](https://github.com/achalpandeyy/OceanFFT)
- [Platinguin/Godot-Water-Shader-Prototype](https://github.com/Platinguin/Godot-Water-Shader-Prototype/)
- [Crest](https://github.com/wave-harmonic/crest)

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
- [Mary Yingst, Jennifer R. Alford, Ian Parberry - Very Fast Real-Time Ocean Wave Foam Rendering Using Halftoning](https://ianparberry.com/techreports/LARC-2011-05.pdf)
- [Jump Trajectory - Ocean waves simulation with Fast Fourier transform](https://www.youtube.com/watch?v=kGEqaX4Y4bQ)
