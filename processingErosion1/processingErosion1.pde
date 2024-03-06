class TerrainCell {
  float terrain;
  float water;
}

final static int TERRAIN_WIDTH = 256;
final static int TERRAIN_HEIGHT = 256;
final static int TERRAIN_SIZE = TERRAIN_WIDTH * TERRAIN_HEIGHT;

TerrainCell [] map = new TerrainCell[TERRAIN_SIZE];

PImage terrainColorMap;
float scale1 = 0.005;  // perlin scale a
float scale2 = 0.002;  // perlin scale b
float layerMix = 0.8;  // 0...1.  closer to 1, more layer1 is used.

int rainPerStep = 50;  // drops per frame
float waterDensityScale = 0.200;

float erosion = 1;
boolean rainOn=true;
boolean drawWater=true;
boolean drawTerrain=true;
boolean erodeOn=true; 

float mapScale = 2.0;
float rx = PI/3, rz = 0;

void setup() {
  size(800,800,P3D);
  randomSeed(0xDEAD);
  noiseSeed(0xBEEF);
  
  makeTerrainMap();
  updateHeightColorMap();
}

void draw() {
  background(0);
  
  if(rainOn) rain();
  flow();
  
  translate(width/2,height/2);
  rotateX(rx);
  rotateZ(rz);
  scale(mapScale);
  translate(-TERRAIN_WIDTH/2,-TERRAIN_HEIGHT/2,-128);
 
  noStroke();
  
  if(drawTerrain) drawTerrainMap();
  if(drawWater) drawWaterMap();
}


void keyReleased() {
  if(key == '1') rainOn = !rainOn;
  if(key == '2') drawWater = !drawWater;
  if(key == '3') drawTerrain = !drawTerrain;
  if(key == '4') erodeOn = !erodeOn;
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
  println("top="+top);

  terrainColorMap = createImage(TERRAIN_WIDTH,TERRAIN_HEIGHT,RGB);
  top = 255/top;
  for(i=0;i<TERRAIN_SIZE;++i) {
    map[i].terrain *= top;
    terrainColorMap.pixels[i] = color(map[i].terrain);
  }
  
  terrainColorMap.updatePixels();
}


color heightColor(float value) {
  // Define your color ranges
  color brown = color(165, 42, 42); // A standard brown color
  color green = color(0, 128, 0);   // A mid-range green color
  color white = color(255);         // Pure white

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
      i++;
    }
  }
  terrainColorMap.updatePixels();
}


int addr(int x,int y) {
  //if(x<0||x>=TERRAIN_WIDTH) throw new IllegalArgumentException("oob x");
  //if(y<0||y>=TERRAIN_HEIGHT) throw new IllegalArgumentException("oob y");
  return (y*TERRAIN_WIDTH)+x;
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

// return index offset of downhill direction.
PVector findDownhill(int x,int y) {
    float minValue = effectiveHeight(x, y); // Starting with the current value
    PVector direction = new PVector(0, 0); // Default to no movement if all values are equal

    // Loop through adjacent pixels
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            if(i==0 && j==0) continue;  // ignore center pixel, we have that already
            var u = x+i;
            var v = y+j;
            // are we inside the map?
            if (u >= 0 && u < TERRAIN_WIDTH && v >= 0 && v < TERRAIN_HEIGHT) {
                // yes, check effective height.
                float adjacentValue = effectiveHeight(u, v);
                if (adjacentValue < minValue) {
                    minValue = adjacentValue;
                    direction.set(i,j);
                }
            } else {
              // off edge of map
              minValue = 0;
              direction.set(i,j);
              return direction;
            }
        }
    }

    return direction; // Returns the direction as a vector
}


// add water to the map
void rain() { //<>//
  for(int i=0;i<rainPerStep;++i) {
    int v = (int)random(0,TERRAIN_SIZE);
    map[v].water++;
  }
}


// make water move downhill and distribute evenly
void flow() {
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      // get water at this spot
      var a = addr(ax,ay);
      var wa = waterLevel(a);
      if(wa==0) continue;
      
      // get downhill
      PVector dir = findDownhill(ax,ay);
      int bx = (int)(ax+dir.x);
      int by = (int)(ay+dir.y);
      if(bx<0 || bx>=TERRAIN_WIDTH || by<0 || by>=TERRAIN_HEIGHT) {
        // off edge of map, vanish when rain is on.
        if(rainOn) map[a].water = 0;
        continue;
      }
      var b = addr(bx,by);
      if(a==b) continue;

      // is water higher at A than B?      
      var eha = effectiveHeight(a);
      var ehb = effectiveHeight(b);
      var eh = eha-ehb;
      var waterMoved = min(wa, eh/2);  // don't move more than is actually here.
      if(waterMoved>0) {
        // move water to downhill spot
        map[a].water -= waterMoved;
        map[b].water += waterMoved;
        
        if(erodeOn) erodeTerrain(a,b,waterMoved);
      }
    }
  }
}


void erodeTerrain(int a,int b,float waterMoved) {
  // is there a height difference?
  var ta = terrainLevel(a);
  var hDiff = ta - terrainLevel(b);
  if(hDiff>0) {
    var v = sin(hDiff/255);
    // move earth to downhill spot
    float earthMoved = min(ta, erosion * waterMoved * v);
    adjustTerrain(a,-earthMoved);
    adjustTerrain(b,earthMoved);
  }
}

void adjustTerrain(int a,float earthMoved) {
  map[a].terrain += earthMoved;
  map[a].terrain = min(max(map[a].terrain,0),255);
}

void drawTerrainMap() {
  for(int y=0;y<TERRAIN_HEIGHT-1;++y) {
    beginShape(TRIANGLE_STRIP);
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      var a = addr(x,y);
      fill(terrainColorMap.pixels[a]);
      vertex(x,(y  ),map[a].terrain);
      var b = a+TERRAIN_WIDTH;
      fill(terrainColorMap.pixels[b]);
      vertex(x,(y+1),map[b].terrain);
    }
    endShape();
  }
}

void drawWaterMap() {
  int i=0;
  for(int y=0;y<TERRAIN_HEIGHT-1;++y) {
    beginShape(TRIANGLE_STRIP);
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      waterPixel(x,y,i);
      waterPixel(x,y+1,i+TERRAIN_WIDTH);
      i++;
    }
    endShape();
  }
}

void waterPixel(int x,int y,int i) {
  var wa = waterLevel(i);
  if(wa<waterDensityScale/2) wa = 0;
  
  var wa2 = map(wa,0,1,0,255);//map(wa, waterDensityScale/2,10,0,255);
  fill(0,0,255,wa2);

  var ha = effectiveHeight(i);
  vertex(x,y,ha);
}
