//--------------------------------------------
// water erosion in Processing.
// a nearly exact copy of https://github.com/Huw-man/Interactive-Erosion-Simulator-on-GPU
// dan@marginallyclever.com 2024-03-05
//--------------------------------------------

final static int TERRAIN_WIDTH = 256;
final static int TERRAIN_HEIGHT = 256;
final static int TERRAIN_SIZE = TERRAIN_WIDTH * TERRAIN_HEIGHT;

float GRAVITY = -9.81;  //m/s/s
float scale1 = 0.006;  // perlin scale a
float scale2 = 0.02;  // perlin scale b
float layerMix = 0.25;  // 0...1.  closer to 1, more layer1 is used.
float depthFactor = 3.0;
float noiseFactor = 2.0;
float maxHeightDifference = 0.6f;

int rainPerStep = 2000;  // drops per frame
float waterDensityScale = 1.00;

float mapScale = 550.0;
float rx = PI/3, rz = 0;
float dt = 0.03;

float sedimentCapacityConstant = 0.3;
float dissolvingConstant = 0.3;
float depositionConstant = 0.3;
float evaporationConstant = 0.95;
float pipeCrossSection = 0.6;
float pipeLength = 1.0;

Terrain map0, map1;

boolean rainOn=true;
boolean drawWater=true;
boolean erodeOn=false;
boolean evaporateOn=true;
boolean paused=true;
boolean showMesh=false;

boolean drawTerrain=true;
int terrainViewMode=0;
int waterViewMode=0;

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
      updateAllErosion();
      map0.updateAllSlope();
      moveAllSediment();
    }
    if(evaporateOn) {
      updateAllEvaporation();
    }
    smoothAll();
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
    switch(terrainViewMode) {
    case 0:  map0.updateColorMapTerrain();  break;
    case 1:  map0.updateColorMapFlux();  break;
    case 2:  map0.updateColorMapVelocity();  break;
    case 3:  map0.updateColorMapHeightChange();  break;
    default: break;
    }
    map0.drawTerrainMap();
  }
  noStroke();
  if(drawWater) {
    switch(waterViewMode) {
      case 0:  map0.updateWaterColorMap();  break;
      case 1:  map0.updateSedimentMap();  break;
      default: break;
    }
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


void keyReleased() {
  if(key == ' ') paused = !paused;
  if(key == '1') rainOn = !rainOn;
  if(key == '2') drawWater = !drawWater;
  if(key == '3') drawTerrain = !drawTerrain;
  if(key == '4') erodeOn = !erodeOn;
  if(key == '5') evaporateOn = !evaporateOn;
  //if(key == '6') map0.report();
  if(key == '7') showMesh = !showMesh;
  if(key == '8') terrainViewMode = (terrainViewMode+1)%4;
  if(key == '9') waterViewMode = (waterViewMode+1)%2;
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


// flux is water pressure in and out of a cell.
void updateAllFlux() {
  // update the four outflows from this cell.
  for(int y=0;y<TERRAIN_HEIGHT;++y) {
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      updateFlux(x,y,0);  // east
      updateFlux(x,y,1);  // north
      updateFlux(x,y,2);  // west
      updateFlux(x,y,3);  // south
    }
  }
  
  // scale the outflows.
  for(int y=0;y<TERRAIN_HEIGHT;++y) {
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      updateFlux2(x,y);
    }
  }
}


/**
 * Update the "flux" (flow velocity) between this cell (a) and neighbor cells (b).  
 * @param a this cell
 * @param b adjacent cell
 * @param dir direction (0=east,1=north,2=west,3=south)
 */
void updateFlux(int x,int y,int direction) {
  // walls of the world have zero outgoing flux.
       if(direction==0 && x+1>TERRAIN_WIDTH-1 ) return;
  else if(direction==1 && y-1<0               ) return;
  else if(direction==2 && x-1<0               ) return;
  else if(                y+1>TERRAIN_HEIGHT-1) return;
  
  var a = addr(x,y);
  var b = getDirectionIndex(x,y,direction);
  var ea = map0.effectiveHeight(a);
  var eb = map0.effectiveHeight(b);
  var hDiff = eb-ea;
  
  var v = map0.map[a].flux[direction] + hDiff * dt * GRAVITY;// * pipeCrossSection / pipeLength;
  
  map0.map[a].flux[direction] = max(0, v);
}


void updateFlux2(int x,int y) {
  // scale flux
  var mapCell = map0.map[addr(x,y)]; 
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
  for(int y=0;y<TERRAIN_HEIGHT;++y) {
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      updateVelocity(x,y);
    }
  }
}


void updateVelocity(int x,int y) {
  float fromE = (x>=TERRAIN_WIDTH ) ? 0 : map0.getFlux(x,y,0,2);
  float fromN = (y< 0             ) ? 0 : map0.getFlux(x,y,1,3);
  float fromW = (x< 0             ) ? 0 : map0.getFlux(x,y,2,0);
  float fromS = (y>=TERRAIN_HEIGHT) ? 0 : map0.getFlux(x,y,3,1);
  
  int a = addr(x,y);
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
  
  mapCell.vx = vx;// / mapCell.water2; 
  mapCell.vy = vy;// / mapCell.water2;
}


void updateAllErosion() {
  for(int y=0;y<TERRAIN_HEIGHT;++y) {
    for(int x=0;x<TERRAIN_WIDTH;++x) {
      updateErosion(x,y);
    }
  }
}


void updateErosion(int x,int y) {
  int i = addr(x,y);
  var mapCell = map0.map[i]; 
  
  // how much sediment is picked up?  aka the "sediment transport capacity"
  float sedimentTransportCapacity = getSedimentTransportCapacity(x,y);
  
  var diff = sedimentTransportCapacity - mapCell.sediment;
  if( diff > 0 ) {
    // Room for more soil in water.  Some soil dissolves into water
    float change = dissolvingConstant * diff / ( heightFactor(mapCell) * noiseFactor(i) ); 
    
    mapCell.terrain = max(0,mapCell.terrain - change); 
    mapCell.sediment = max(0, mapCell.sediment + change);
  } else {
    // not enough room, some soil is deposited
    var change = -(depositionConstant * diff);
    mapCell.terrain = max(0,mapCell.terrain + change); 
    mapCell.sediment = max(0, mapCell.sediment - change);
  }
}


float heightFactor(TerrainCell mapCell) {
  return 1.0 + max(mapCell.terrainOriginal - mapCell.terrain,0) * depthFactor;
}


float noiseFactor(int i) {
  return 1.0 + (noise(i) + 1.0) * noiseFactor;
}


void updateAllEvaporation() {
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      updateEvaporation(ax,ay);
    }
  }
}


void updateEvaporation(int ax,int ay) {
  var mapCell = map0.map[addr(ax,ay)]; 
  mapCell.water = max(0, mapCell.water * ( 1.0f - evaporationConstant * dt)); 
}


float getSedimentTransportCapacity(int ax,int ay) {
  var mapCell = map0.map[addr(ax,ay)]; 
  float slope = (mapCell.sinAngle);
  
  // how much sediment is picked up?  aka the "sediment transport capacity"
  return sedimentCapacityConstant
    * (0.15+sin(slope)) 
    * max(0.15,lengthOf(mapCell.vx,mapCell.vy))
    * constrain(mapCell.water,0,1);
}


void moveAllSediment() {
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      moveSediment(ax,ay);
    }
  }
  
  for(int i=0;i<TERRAIN_SIZE;++i) {
    map0.map[i].sediment = constrain(map0.map[i].sediment2,0,255);
  }
}


void moveSediment(int ax,int ay) {
  var mapCell = map0.map[addr(ax,ay)]; 
  // move sediment, pulling a small amount from neighbors.
  float bx = constrain(ax - mapCell.vx * dt,0,TERRAIN_WIDTH -1);
  float by = constrain(ay - mapCell.vy * dt,0,TERRAIN_HEIGHT-1);
  
  int fbx = (int)floor(bx);
  int fby = (int)floor(by);
  int cbx = (int)ceil(bx);
  int cby = (int)ceil(by);
  
  float topLeft     = map0.sedimentLevel(fbx, fby);
  float topRight    = map0.sedimentLevel(cbx, fby);
  float bottomLeft  = map0.sedimentLevel(fbx, cby);
  float bottomRight = map0.sedimentLevel(cbx, cby);
  
  float sTop        = (bx - fbx) * topRight    + (cbx - bx) * topLeft;
  float sBottom     = (bx - fbx) * bottomRight + (cbx - bx) * bottomLeft;
  mapCell.sediment2 = (by - fby) * sTop        + (cby - by) * sBottom;
}


void smoothAll() {
  for(int ay=0;ay<TERRAIN_HEIGHT;++ay) {
    for(int ax=0;ax<TERRAIN_WIDTH;++ax) {
      smoothCell(ax,ay);
    }
  }
}


void smoothCell(int ax,int ay) {
  var mapCell = map0.map[addr(ax,ay)]; 
  
  int w = constrain(ax - 1,0,TERRAIN_WIDTH -1);
  int e = constrain(ax + 1,0,TERRAIN_WIDTH -1);
  int n = constrain(ay - 1,0,TERRAIN_HEIGHT-1);
  int s = constrain(ay + 1,0,TERRAIN_HEIGHT-1);
  float wh = map0.map[addr(w,ay)].terrain;
  float eh = map0.map[addr(e,ay)].terrain;
  float nh = map0.map[addr(ax,n)].terrain;
  float sh = map0.map[addr(ax,s)].terrain;
  
  float dw = mapCell.terrain - wh;
  float de = mapCell.terrain - eh;
  float dn = mapCell.terrain - nh;
  float ds = mapCell.terrain - sh;
  
  float x_crv = dw*de;
  float y_crv = dn*ds;
  
  if( ( (abs(dw) > maxHeightDifference || abs(de) > maxHeightDifference) && x_crv > 0) ||
      ( (abs(dn) > maxHeightDifference || abs(ds) > maxHeightDifference) && y_crv > 0) ) {
    mapCell.terrain = ( mapCell.terrain + wh + eh + nh + sh) / 5.0; // Set height to average
  }
}


float lengthOf(float x,float y) {
  return sqrt(x*x + y*y);
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
  vertex(x+cell.vx*dt*50, y+cell.vy*dt*50, h+1 );
  endShape();
  
  //println(x+","+y+" = "+(cell.vx/dt)+","+(cell.vy/dt));
}
