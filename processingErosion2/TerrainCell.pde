
class TerrainCell {
  float terrainOriginal;  // land height
  float terrain;  // land height
  float water;
  float water2;
  float sediment;  // dissolved in water
  float sediment2;  // dissolved in water
  float [] flux = new float[4];  // water pressure in each direction
  float inFlow;  // pressure in   
  float outFlow;  // pressure out
  float vx, vy;  // actual water velocity after calculating pressure differences.
  float sx, sy;  // slope of terrain
  float sinAngle;  // slope as an angle in radians.
  
  String toString() {
    return 
      nf(terrain,0,3)+","+
      nf(water,0,3)+","+
      nf(sediment,0,3)+","+
      nf(flux[0],0,3)+","+
      nf(flux[1],0,3)+","+
      nf(flux[2],0,3)+","+
      nf(flux[3],0,3)+","+
      nf(vx,0,3)+","+
      nf(vy,0,3)+","+
      nf(inFlow,0,3)+","+
      nf(outFlow,0,3)+",";
  }
}
