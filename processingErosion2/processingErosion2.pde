//--------------------------------------------
// water erosion in Processing.
// a nearly exact copy of https://github.com/Huw-man/Interactive-Erosion-Simulator-on-GPU
// dan@marginallyclever.com 2024-03-05
//--------------------------------------------

class TerrainCell {
  float terrain;  // land height
  float water;
  float sediment;  // dissolved in water
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

final static int TERRAIN_WIDTH = 256;
final static int TERRAIN_HEIGHT = 256;
final static int TERRAIN_SIZE = TERRAIN_WIDTH * TERRAIN_HEIGHT;

TerrainCell [] map = new TerrainCell[TERRAIN_SIZE];

float GRAVITY = -9.81;  //m/s/s
PImage terrainColorMap;
float scale1 = 0.005;  // perlin scale a
float scale2 = 0.002;  // perlin scale b
float layerMix = 0.8;  // 0...1.  closer to 1, more layer1 is used.

int rainPerStep = 300;  // drops per frame
float waterDensityScale = 1.00;

float erosion = 1;
boolean rainOn=true;
boolean drawWater=true;
boolean drawTerrain=true;
boolean erodeOn=true; 

float mapScale = 2.0;
float rx = PI/3, rz = 0;
float dt = 0.03;

float sedimentCapacityConstant = 0.03;
float dissolvingConstant = 0.03;
float depositionConstant = 0.03;
float evaporationConstant = 0.095;
float pipeCrossSection = 0.6;
float pipeLength = 1.0;

int updateCount =0;

void setup() {
  size(800,800,P3D);
  //randomSeed(0xDEAD);
  //noiseSeed(0xBEEF);
  
  makeTerrainMap();
  updateHeightColorMap();
}

void draw() {
  background(0);
  
  if(rainOn) rain();
  // make water move downhill and distribute evenly
  updateAllFlux();
  updateAllVelocity();
  updateAllErosionAndEvaporation();
  
  ambientLight(128,128,128);
  directionalLight(128,128,128, 0, 0, -1);
  translate(width/2,height/2,450);
  rotateX(rx);
  rotateZ(rz);
  translate(-TERRAIN_WIDTH/2,-TERRAIN_HEIGHT/2,-128);
 
  noStroke();
  
  if(drawTerrain) drawTerrainMap();
  if(drawWater) drawWaterMap();
  
  //if(((updateCount++)%100)==0) {
    updateHeightColorMap();
  //}
}


void keyReleased() {
  if(key == '1') rainOn = !rainOn;
  if(key == '2') drawWater = !drawWater;
  if(key == '3') drawTerrain = !drawTerrain;
  if(key == '4') erodeOn = !erodeOn;
  if(key == '5') report();
  if(key == '+') mapScale*=1.1;
  if(key == '-') mapScale/=1.1;
}


void report() {
  println("y,x,terrain,water,sediment,Flux 0,Flux 1,Flux 2,Flux 3,vx,vy,inFlow,outFlow,diff");

  for(int y=0;y<TERRAIN_HEIGHT;++y) {
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      print(y+","+x+",");
      println(map[addr(x,y)]);
    }
  }
}

void mouseDragged() {
  rz += (mouseX - pmouseX) * 0.01;
  rx += (mouseY - pmouseY) * 0.01;
  rx = min(rx,PI);
  rx = max(rx,0);
}

void makeTerrainMap() {
  float top = 0;
  int i=0;
  for(int y=0;y<TERRAIN_HEIGHT;++y) {
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      var v = (noise(scale1 * x, scale1 * y)*(    layerMix) +
               noise(scale2 * x, scale2 * y)*(1.0-layerMix)
               )* 255;
      var c = new TerrainCell();
      map[i++] = c;
      
      top = max(v,top);
      c.terrain = v;
    }
  }

  terrainColorMap = createImage(TERRAIN_WIDTH,TERRAIN_HEIGHT,RGB);
}


color heightColor(float value) {
  // Define your color ranges
  color brown = color(0x36, 0x1b, 0x00);  // A standard brown color
  color green = color(0x96, 0x4b, 0x00);  // A mid-range green color
  color white = color(0xff, 0xff, 0xff);  // Pure white

  // Normalize the value to be between 0 and 1 for interpolation
  float normalizedValue = map(value, 0, 255, 0, 1);

  // Determine the color based on the altitude value
  if (normalizedValue < 0.5) {
    // Scale the value to be between 0 and 1 within this subrange
    float scaledValue = map(normalizedValue, 0, 0.5, 0, 1);
    // Interpolate between brown and green
    return lerpColor(brown, green, scaledValue);
  } else {
    // Scale the value to be between 0 and 1 within this subrange
    float scaledValue = map(normalizedValue, 0.5, 1, 0, 1);
    // Interpolate between green and white
    return lerpColor(green, white, scaledValue);
  }  
}


void updateHeightColorMap() {
  int i=0;
  for(int y=0;y<TERRAIN_HEIGHT;++y) {
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      terrainColorMap.pixels[i] = heightColor(map[i].terrain);
      updateSlope(x,y);
      i++;
    }
  }
  terrainColorMap.updatePixels();
}


int addr(int x,int y) {
  //if(x<0||x>=TERRAIN_WIDTH) throw new IllegalArgumentException("oob x");
  //if(y<0||y>=TERRAIN_HEIGHT) throw new IllegalArgumentException("oob y");
  return y*TERRAIN_WIDTH + x;
}


void updateSlope(int x,int y) {
  int a = addr(x,y);

  float dx = terrainLevel(constrain(x+1,0,TERRAIN_WIDTH-1),y)
           - terrainLevel(constrain(x-1,0,TERRAIN_WIDTH-1),y);
  float dy = terrainLevel(x,constrain(y+1,0,TERRAIN_HEIGHT-1))
           - terrainLevel(x,constrain(y-1,0,TERRAIN_HEIGHT-1));
  
  var mapCell = map[a];
  
  mapCell.sx = dx;
  mapCell.sy = dy;
  mapCell.sinAngle = sqrt(dx*dx+dy*dy) / sqrt(1+ dx*dx+dy*dy);
}


// get the slope at (a) in the direction of pressure (v)
float getSlope(int ax,int ay) {
  var mapCell = map[addr(ax,ay)];
  return mapCell.sinAngle;
}


float terrainLevel(int a) {
  return map[a].terrain;
}


float terrainLevel(int x,int y) {
  return terrainLevel(addr(x,y));
}


// water level (not including terrain height) 
float waterLevel(int a) {
  return map[a].water * waterDensityScale;
}


float waterLevel(int x,int y) {
  return waterLevel(addr(x,y));
}


// terrain height + water height
float effectiveHeight(int index) {
  return terrainLevel(index) + waterLevel(index);
}


float effectiveHeight(int x,int y) {
  var a = addr(x,y);
  return effectiveHeight(a);
}

 
float sedimentLevel(int x,int y) {
  return map[addr(x,y)].sediment;
}


// add water to the map
void rain() { //<>//
  for(int i=0;i<rainPerStep;++i) {
    int v = (int)random(0,TERRAIN_SIZE);
    map[v].water += dt;
  }
}


void updateAllErosionAndEvaporation() {
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      updateErosionAndEvaporation(ax,ay);
    }
  }
}


void updateErosionAndEvaporation(int ax,int ay) {
  var mapCell = map[addr(ax,ay)]; 
  
  float slope = abs(getSlope(ax,ay));
  
  // how much sediment is picked up?  aka the "sediment transport capacity"
  float sedimentTransportCapacity = sedimentCapacityConstant
      * sin(slope) 
      * lengthOf(mapCell.vx,mapCell.vy)
      * constrain(mapCell.water,0,1);
  
  var diff = sedimentTransportCapacity - mapCell.sediment;
  if( diff > 0 ) {
    // some soil dissolves into water
    
    var change = dissolvingConstant * diff;
    mapCell.terrain  -= change;
    mapCell.sediment += change;
  } else {
    // some soil is deposited
    var change = depositionConstant * diff;
    mapCell.terrain  -= change;
    mapCell.sediment += change;
  }
  
  mapCell.water *= 1 - evaporationConstant * dt; 
  
  // move sediment, pulling a small amount from neighbors.
  float bx = constrain(ax - mapCell.vx * dt,0,TERRAIN_WIDTH -1);
  float by = constrain(ay - mapCell.vy * dt,0,TERRAIN_HEIGHT-1);
  
  float topLeft     = sedimentLevel((int)floor(bx), (int)floor(by));
  float topRight    = sedimentLevel((int)ceil (bx), (int)floor(by));
  float bottomLeft  = sedimentLevel((int)floor(bx), (int)ceil (by));
  float bottomRight = sedimentLevel((int)ceil (bx), (int)ceil (by));
  
  float sTop    = (bx - floor(bx)) * topRight    + (ceil(bx)-bx)*topLeft;
  float sBottom = (bx - floor(bx)) * bottomRight + (ceil(bx)-bx)*bottomLeft;
  
  mapCell.sediment = (by-floor(by))*sTop + (ceil(by)-by)*sBottom;
}


void updateAllFlux() {
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      updateFlux(ax,ay);
    }
  }
}

void updateFlux(int ax,int ay) {
  // east
  if(ax<TERRAIN_WIDTH-1) updateFlux(ax,ay,0);
  // north
  if(ay>0) updateFlux(ax,ay,1);
  // west
  if(ax>0) updateFlux(ax,ay,2);
  // south
  if(ay<TERRAIN_HEIGHT-1) updateFlux(ax,ay,3);
  
  // scale flux
  var mapCell = map[addr(ax,ay)]; 
  float sum = 0;
  for(float out : mapCell.flux) {
    sum += out;
  }
  
  float k = (sum==0) ? 0 : min(1, mapCell.water / (sum*dt) );
  
  for(int i=0;i<mapCell.flux.length;++i) {
    mapCell.flux[i] *= k;
  }
}


/**
 * "flux" (flow velocity) between two cells.
 * @param a this cell
 * @param b adjacent cell
 * @param dir direction (0=east,1=north,2=west,3=south)
 */
void updateFlux(int ax,int ay,int direction) {
  var a = addr(ax,ay);
  var b = getDirectionIndex(ax,ay,direction);
  
  var ea = effectiveHeight(a);
  var eb = effectiveHeight(b);
  var hDiff = eb-ea;
  map[a].flux[direction] = max(0, map[a].flux[direction] + dt * pipeCrossSection * (GRAVITY * hDiff) / pipeLength ); 
}


void updateAllVelocity() {
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      updateVelocity(ax,ay);
    }
  }
}


void updateVelocity(int ax,int ay) {
  int a = addr(ax,ay);
  TerrainCell mapCell = map[a];
  
  mapCell.inFlow = 0;
  mapCell.outFlow = 0;
  mapCell.vx=0;
  mapCell.vy=0;
  int cx=0;
  int cy=0;
  
  if(ax>0) {
    // check west flow
    var w = getFlux(ax,ay,2);
    var e = mapCell.flux[2];
    mapCell.inFlow += w;
    mapCell.outFlow += e;
    mapCell.vx += w - e;
    cx++;
  }
  if(ax<TERRAIN_WIDTH-1) {
    // check east flow
    var e = getFlux(ax,ay,0);
    var w = mapCell.flux[0];
    mapCell.inFlow += e;
    mapCell.outFlow += w;
    mapCell.vx += w - e;
    cx++;
  }
  
  if(ay>0) {
    // check north flow
    var n = getFlux(ax,ay,1);
    var s = mapCell.flux[1]; 
    mapCell.inFlow += n;
    mapCell.outFlow += s;
    mapCell.vy += s - n;
    cy++;
  }
  if(ay<TERRAIN_HEIGHT-1) {
    // check south flow
    var s = getFlux(ax,ay,3);
    var n = mapCell.flux[3];
    mapCell.inFlow += s;
    mapCell.outFlow += n;
    mapCell.vy += s - n;
    cy++;
  }
  
  mapCell.vx /= cx;
  mapCell.vy /= cy;
  
  // vx/vy is now the water pressure through this cell.
  
  // change in water level in this square
  mapCell.water += dt * (mapCell.inFlow - mapCell.outFlow);
  mapCell.water = max(0,mapCell.water);
}


float lengthOf(float x,float y) {
  return sqrt(x*x + y*y);
}


// If I ask for the flux from the north, I should get map[north].flux[south].
// This should be true for all directions.
float getFlux(int x,int y,int direction) {
  int adjacent = getDirectionIndex(x,y,direction);
  int opposite = (direction+2)%4;
  return map[adjacent].flux[opposite];
}


int getDirectionIndex(int x,int y,int direction) {
  switch(direction) {
    case 0:  x++;  break;  // 0 east
    case 1:  y--;  break;  // 1 north
    case 2:  x--;  break;  // 2 west
    case 3:  y++;  break;  // 3 south
    default:  throw new IllegalArgumentException("direction must be 0-3");
  }
  
  x = constrain(x,0,TERRAIN_WIDTH-1);
  y = constrain(y,0,TERRAIN_HEIGHT-1);
  return addr(x,y);
}


void drawTerrainMap() {
  int i=0;
  int j=TERRAIN_WIDTH;
  for(int y=0;y<TERRAIN_HEIGHT-1;++y) {
    beginShape(TRIANGLE_STRIP);
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      terrainPixel(x,y  ,i);
      terrainPixel(x,y+1,j);
      ++i;
      ++j;
    }
    endShape();
  }
}

void terrainPixel(int x,int y,int a) {
  var mapCell = map[a];
  fill(terrainColorMap.pixels[a]);
  normal(mapCell.sx,mapCell.sy,1);
  vertex(x,(y  ),map[a].terrain);
}


void drawWaterMap() {
  int i=0;
  int j=TERRAIN_WIDTH;
  for(int y=0;y<TERRAIN_HEIGHT-1;++y) {
    beginShape(TRIANGLE_STRIP);
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      waterPixel(x,y  ,i);
      waterPixel(x,y+1,j);
      i++;
      j++;
    }
    endShape();
  }
}


void waterPixel(int x,int y,int i) {
  var wa = waterLevel(i);
  //if(wa<waterDensityScale/2) wa = 0;
  
  var mapCell = map[i];
  
  var wa2 = map(wa*10,0,5,0,255);
  //var wa2 = map(wa, waterDensityScale/2,waterDensityScale*5,0,255);
  //var wa2=255;
  var s = map(mapCell.sediment,0,sedimentCapacityConstant,0,255);
  fill(0,s,255-s,wa2);

  var ha = 1+effectiveHeight(i);
  vertex(x,y,ha);
}
