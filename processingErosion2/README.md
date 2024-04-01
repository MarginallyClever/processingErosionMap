# Erosion simulation

A Processing version of https://github.com/Huw-man/Interactive-Erosion-Simulator-on-GPU

## controls

spacebar - toggle pause
1 - toggle rain (default on)
2 - toggle show water (default on)
3 - toggle show terrain (default on)
4 - toggle erosion (default off)
5 - toggle evaporation (default on)
7 - toggle show triangle mesh (default off)
8 - cycle terrain view.  normal, flux (water pressure), velocity (water movement), map height change.
9 - cycle water view.  normal, sediment.

mouse - turn world
mouse wheel - scale world


## notes

Original author has not responded to my questions or raised issues.

Paper says one thing and does another, adding a smoothing step and a few numerical constants.

Processing has a method called noise(x,y) to create Perlin noise.  I have found in my testing
that it is not very smooth.  the resulting values are "rough" and create unexpected repeating
patterns in the terrain.  They're not immediately visible to the naked eye until water begins
to flow and then it will look oddly regular.  I have tried Simplex noise with better results.
I have also tried noisier terrain (less scaling) with equally good results.  Your mileage may
vary.