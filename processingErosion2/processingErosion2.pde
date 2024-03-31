//--------------------------------------------
// water erosion in Processing.
// a nearly exact copy of https://github.com/Huw-man/Interactive-Erosion-Simulator-on-GPU
// dan@marginallyclever.com 2024-03-05
//--------------------------------------------

final static int TERRAIN_WIDTH = 16;
final static int TERRAIN_HEIGHT = 16;
final static int TERRAIN_SIZE = TERRAIN_WIDTH * TERRAIN_HEIGHT;

float GRAVITY = -9.81;  //m/s/s
float scale1 = 0.008;  // perlin scale a
float scale2 = 0.002;  // perlin scale b
float layerMix = 0.75;  // 0...1.  closer to 1, more layer1 is used.

int rainPerStep = 300;  // drops per frame
float waterDensityScale = 1.00;

float mapScale = 550.0;
float rx = PI/3, rz = 0;
float dt = 0.03;

float sedimentCapacityConstant = 0.03;
float dissolvingConstant = 0.03;
float depositionConstant = 0.03;
float evaporationConstant = 0.095;
float pipeCrossSection = 0.6;
float pipeLength = 1.0;

Terrain map0, map1;

boolean rainOn=true;
boolean drawWater=true;
boolean erodeOn=false;
boolean paused=true;
boolean showMesh=false;

boolean drawTerrain=true;

void setup() {
  size(800,800,P3D);
  
  map0 = new Terrain();
  map1 = new Terrain();
  map0.updateAllSlope();
  
  assert(getDirectionIndex(1,2,0)==addr(2,2));
  assert(getDirectionIndex(2,3,1)==addr(2,2));
  assert(getDirectionIndex(3,2,2)==addr(2,2));
  assert(getDirectionIndex(2,1,3)==addr(2,2));
}


void draw() {
  background(0);
  
  if(!paused) {
    if(rainOn) rain();
    // make water move downhill and distribute evenly
    updateAllFlux();
    updateAllVelocity();
    if(erodeOn) {
      updateAllErosionAndEvaporation();
      moveAllSediment();
      map0.updateAllSlope();
    }
  }
  
  beginCamera();
  camera();
  translate(width/2,height/2,mapScale);
  rotateX(rx);
  rotateZ(rz);
  endCamera();
  
  translate(-TERRAIN_WIDTH/2,-TERRAIN_HEIGHT/2,-128);
  
  //ambientLight(128,128,128);
  //directionalLight(128,128,128, 0, 0, -1);
  
  if(showMesh) {
    strokeWeight(1);
    stroke(255,255,255,255);
  } else {
    noStroke();
    fill(255);
  }
  if(drawTerrain) {
    //map0.updateColorMapTerrain();
    map0.updateColorMapFlux();
    //map0.updateColorMapVelocity();
    map0.drawTerrainMap();
  }
  noStroke();
  if(drawWater) {
    map0.updateWaterColorMap();
    map0.drawWaterMap();
  }
  if(paused) {
    drawCellData();
  }
}


int addr(int x,int y) {
  //if(x<0||x>=TERRAIN_WIDTH) 
    //throw new IllegalArgumentException("oob x");
  //if(y<0||y>=TERRAIN_HEIGHT) 
    //throw new IllegalArgumentException("oob y");
  return y*TERRAIN_WIDTH + x;
}


// go `direction` from cell (x,y) and get the address of that new cell.
int getDirectionIndex(int x,int y,int direction) {
  switch(direction) {
    case 0:  x++;  break;  // 0 east
    case 1:  y--;  break;  // 1 north
    case 2:  x--;  break;  // 2 west
    case 3:  y++;  break;  // 3 south
    default:  throw new IllegalArgumentException("direction must be 0-3");
  }
  
  return addr(x,y);
}


void drawCellData() {
  int x = (TERRAIN_WIDTH-1) * mouseX/width;
  int y = (TERRAIN_HEIGHT-1) * mouseY/height;
  
  int i = addr(x,y);
  TerrainCell cell = map0.map[i];
  float h = map0.effectiveHeight(i);
  
  fill(255,0,0);
  beginShape(LINES);
  stroke(255,0,0);
  vertex( x, y, h+1 );
  stroke(0,255,0);
  vertex(x+cell.vx/dt, y+cell.vy/dt, h+1 );
  endShape();
  
  //println(x+","+y+" = "+(cell.vx/dt)+","+(cell.vy/dt));
}


void keyReleased() {
  if(key == ' ') paused = !paused;
  if(key == '1') rainOn = !rainOn;
  if(key == '2') drawWater = !drawWater;
  if(key == '3') drawTerrain = !drawTerrain;
  if(key == '4') erodeOn = !erodeOn;
  if(key == '5') map0.report();
  if(key == '6') showMesh = !showMesh;
  if(key == '+') mapScale *= 1.1;
  if(key == '-') mapScale /= 1.1;
}

void mouseDragged() {
  rz += (mouseX - pmouseX) * 0.01;
  rx += (mouseY - pmouseY) * 0.01;
  rx = min(rx,PI);
  rx = max(rx,0);
}


void mouseWheel(MouseEvent event) {
  mapScale = constrain(mapScale + event.getCount()*5, 0, 1000);
}


// add water to the map
void rain() {
  for(int i=0;i<rainPerStep;++i) {
    int v = (int)(random(0,TERRAIN_SIZE));
    map0.map[v].water += dt;
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
  var mapCell = map0.map[addr(ax,ay)]; 
  
  float slope = abs(map0.getSlope(ax,ay));
  
  // how much sediment is picked up?  aka the "sediment transport capacity"
  float sedimentTransportCapacity
      = sedimentCapacityConstant
      * (0.15+sin(slope)) 
      * max(0.15,lengthOf(mapCell.vx,mapCell.vy))
      * constrain(mapCell.water,0,1);
  
  var diff = sedimentTransportCapacity - mapCell.sediment;
  if( diff > 0 ) {
    // room for more soil in water.  some soil dissolves into water
    var change = dissolvingConstant * diff;
    mapCell.terrain  -= change;
    mapCell.sediment += change;
  } else {
    // not enough room, some soil is deposited
    var change = depositionConstant * diff;
    mapCell.terrain  += change;
    mapCell.sediment -= change;
  }
  
  mapCell.water *= 1 - evaporationConstant * dt; 
}


void moveAllSediment() {
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      moveSediment(ax,ay);
    }
  }
  
  for(int i=0;i<TERRAIN_SIZE;++i) {
    map0.map[i].sediment = map0.map[i].sediment2;
  }
}


void moveSediment(int ax,int ay) {
  var mapCell = map0.map[addr(ax,ay)]; 
  // move sediment, pulling a small amount from neighbors.
  float bx = constrain(ax - mapCell.vx * dt,0,TERRAIN_WIDTH -1);
  float by = constrain(ay - mapCell.vy * dt,0,TERRAIN_HEIGHT-1);
  
  float topLeft     = map0.sedimentLevel((int)floor(bx), (int)floor(by));
  float topRight    = map0.sedimentLevel((int)ceil (bx), (int)floor(by));
  float bottomLeft  = map0.sedimentLevel((int)floor(bx), (int)ceil (by));
  float bottomRight = map0.sedimentLevel((int)ceil (bx), (int)ceil (by));
  
  float sTop        = (bx - floor(bx)) * topRight    + (ceil(bx)-bx)*topLeft;
  float sBottom     = (bx - floor(bx)) * bottomRight + (ceil(bx)-bx)*bottomLeft;
  mapCell.sediment2 = (by - floor(by)) * sTop        + (ceil(by)-by)*sBottom;
}


// flux is water pressure in and out of a cell.
void updateAllFlux() {
  // update the four outflows from this cell.
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      updateFlux(ax,ay,0);  // east
      updateFlux(ax,ay,1);  // north
      updateFlux(ax,ay,2);  // west
      updateFlux(ax,ay,3);  // south
    }
  }
  
  // scale the outflows.
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      updateFlux2(ax,ay);
    }
  }
}


/**
 * Update the "flux" (flow velocity) between this cell (a) and neighbor cells (b).  
 * @param a this cell
 * @param b adjacent cell
 * @param dir direction (0=east,1=north,2=west,3=south)
 */
void updateFlux(int ax,int ay,int direction) {
  if(ax==0 && ay==0) {
    print(direction+",");
  }
  
  // walls of the world have zero outgoing flux.
  if(direction==0) {
    if(ax+1>TERRAIN_WIDTH-1) return;
  } else if(direction==1) {
    if(ay-1<0) return;
  } else if(direction==2) {
    if(ax-1<0) return;
  } else { // if(direction==3)
    if(ay+1>TERRAIN_HEIGHT-1) return;
  }
  
  var a = addr(ax,ay);
  var b = getDirectionIndex(ax,ay,direction);
  var ea = map0.effectiveHeight(a);
  var eb = map0.effectiveHeight(b);
  var hDiff = eb-ea;
  
  var v = map0.map[a].flux[direction] + dt * (GRAVITY * hDiff) * pipeCrossSection / pipeLength;
  
  if(ax==0 && ay==0) {
    println(a+","
          +b+","
          +ea+","
          +ea+","
          +hDiff+","
          +v+",");
  }
  
  map0.map[a].flux[direction] = max(0, v);
}


void updateFlux2(int ax,int ay) {
  // scale flux
  var mapCell = map0.map[addr(ax,ay)]; 
  float sum = 0;
  for(float out : mapCell.flux) {
    sum += out;
  }
  
  float k = (sum==0) ? 0 : min(1, mapCell.water / sum / dt );
  
  for(int i=0;i<mapCell.flux.length;++i) {
    mapCell.flux[i] *= k;
  }
  
  mapCell.outFlow = sum * k;
}


void updateAllVelocity() {
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      updateVelocity(ax,ay);
    }
  }
}


void updateVelocity(int ax,int ay) {
  float fromE = (ax>=TERRAIN_WIDTH ) ? 0 : map0.getFlux(ax,ay,0,2);
  float fromN = (ay< 0             ) ? 0 : map0.getFlux(ax,ay,1,3);
  float fromW = (ax< 0             ) ? 0 : map0.getFlux(ax,ay,2,0);
  float fromS = (ay>=TERRAIN_HEIGHT) ? 0 : map0.getFlux(ax,ay,3,1);
  
  int a = addr(ax,ay);
  TerrainCell mapCell = map0.map[a];
  mapCell.inFlow = fromE + fromN + fromW + fromS;
  float waterChange = dt * (mapCell.inFlow - mapCell.outFlow);
  
  // change in water level in this square
  float oldWater = mapCell.water;
  mapCell.water  = max(0, oldWater + waterChange    );
  mapCell.water2 = max(0, oldWater + waterChange/2.0);
 
  // get vx/vy, the water pressure through this cell.
  float vx = (fromW + mapCell.flux[0] - mapCell.flux[2] - fromE) / 2.0;
  float vy = (fromN + mapCell.flux[3] - mapCell.flux[1] - fromS) / 2.0;
  
  mapCell.vx = vx / mapCell.water2; 
  mapCell.vy = vy / mapCell.water2;
}


float lengthOf(float x,float y) {
  return sqrt(x*x + y*y);
}
