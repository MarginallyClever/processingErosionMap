final static long SEED = 0xBEEF;

class Terrain {
  public TerrainCell [] map = new TerrainCell[TERRAIN_SIZE];
  public PGraphics terrainColorMap;
  public PGraphics waterColorMap;
  
  Terrain() {
    randomSeed(0xDEAD);
    noiseSeed(SEED);
    createMap();
    //createFlatTerrain();
    //createVYTerrain();
    //createVXTerrain();
    //createConeTerrain();
    //createRandomTerrainSimplex();
    createRandomTerrainPerlin();
    
    setOriginalTerrain();
  
    terrainColorMap = createGraphics(TERRAIN_WIDTH,TERRAIN_HEIGHT);
    waterColorMap = createGraphics(TERRAIN_WIDTH,TERRAIN_HEIGHT);
  }
  
  void createMap() {
    for(int i=0;i<TERRAIN_SIZE;++i) {
      map[i] = new TerrainCell();
    }
  }
  
  
  void createFlatTerrain() {
    int i=0;
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        map[i++].terrain = 128;
      }
    }
  }
  
  
  void createVXTerrain() {
    int tw2 = (TERRAIN_WIDTH/2);
    int i=0;
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        float dx = abs(x-tw2)/(float)tw2;
        
        map[i++].terrain = dx*128;
      }
    }
  }
  
  
  void createVYTerrain() {
    int th2 = (TERRAIN_HEIGHT/2);
    int i=0;
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        float dy = abs(y-th2)/(float)th2;
        
        map[i++].terrain = dy*128;
      }
    }
  }
  
  
  void createConeTerrain() {
    int tw2 = (TERRAIN_WIDTH/2);
    int th2 = (TERRAIN_HEIGHT/2);
    int i=0;
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        float dx = abs(x-tw2)/(float)tw2;
        float dy = abs(y-th2)/(float)th2;
        
        map[i++].terrain = sqrt(dx*dx+dy*dy)*128;
      }
    }
  }
  
  
  void createRandomTerrainSimplex() {
    int i=0;
    for(float y=0;y<TERRAIN_HEIGHT;++y) {
      for(float x=0;x<TERRAIN_WIDTH;++x) {
        float a = (float)OpenSimplex2S.noise3_ImproveXY(SEED,scale1 * x, scale1 * y,0);
        float b = (float)OpenSimplex2S.noise3_ImproveXY(SEED,scale2 * x, scale2 * y,0);
        float c = lerp(a,b,layerMix);
        map[i++].terrain = (c+1) * 128;
      }
    }
  }
  
  
  void createRandomTerrainPerlin() {
    int i=0;
    for(float y=0;y<TERRAIN_HEIGHT;++y) {
      for(float x=0;x<TERRAIN_WIDTH;++x) {
        float a = (float)noise(scale1 * x, scale1 * y);
        float b = (float)noise(scale2 * x, scale2 * y);
        float c = lerp(a,b,layerMix);
        map[i++].terrain = c * 255;
      }
    }
  }
  

  void setOriginalTerrain() {
    for(int i=0;i<TERRAIN_SIZE;++i) {
      map[i].terrainOriginal = map[i].terrain;
    }
  }
  
  
  public void updateColorMapTerrain() {
    terrainColorMap.beginDraw();
    terrainColorMap.noStroke();
    
    int i=0;
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        terrainColorMap.set(x, y, heightColor(map[i++]));
      }
    }
    terrainColorMap.endDraw();
  }
  
  
  public void updateColorMapFlux() {
    terrainColorMap.beginDraw();
    terrainColorMap.noStroke();
    
    int i=0;
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        var mapCell = map0.map[i++];
        color c = color(
          (mapCell.flux[0]+mapCell.flux[2])*128,
          (mapCell.flux[1]+mapCell.flux[3])*128,
          0);
        terrainColorMap.set(x, y, c);
      }
    }
    terrainColorMap.endDraw();
  }
  
  
  public void updateColorMapVelocity() {
    terrainColorMap.beginDraw();
    terrainColorMap.noStroke();
    float scale = 128;
    
    int i=0;
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        var mapCell = map0.map[i++];
        color c = color(
          abs(mapCell.vx*scale),
          abs(mapCell.vy*scale),
          mapCell.sinAngle*scale+128
        );
        terrainColorMap.set(x, y, c);
      }
    }
    terrainColorMap.endDraw();
  }
  
  
  public void updateColorMapHeightChange() {
    terrainColorMap.beginDraw();
    terrainColorMap.noStroke();
    float scale = 64;
    
    int i=0;
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        var mapCell = map0.map[i++];
        float dh = (mapCell.terrainOriginal - mapCell.terrain) * scale + 128;
        color c = color(dh,dh,dh);
        terrainColorMap.set(x, y, c);
      }
    }
    terrainColorMap.endDraw();
  }
  
  
  public void updateAllSlope() {
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        updateSlope(x,y);
      }
    }
  }

  void updateSlope(int x,int y) {
    float dx = map0.terrainLevel(constrain(x+1,0,TERRAIN_WIDTH-1),y)
             - map0.terrainLevel(constrain(x-1,0,TERRAIN_WIDTH-1),y);
    float dy = map0.terrainLevel(x,constrain(y+1,0,TERRAIN_HEIGHT-1))
             - map0.terrainLevel(x,constrain(y-1,0,TERRAIN_HEIGHT-1));
    
    var mapCell = map0.map[addr(x,y)];
    mapCell.sx = dx;
    mapCell.sy = dy;
    mapCell.sinAngle = sqrt(dx*dx + dy*dy) / sqrt(dx*dx + dy*dy + 1.0);
  }
  
  
  color heightColor(TerrainCell mapCell) {
    // Define your color ranges
    color brown = color(0x36, 0x1b, 0x00);  // A standard brown color
    color green = color(0x4b, 0x96, 0x00);  // A mid-range green color
    color white = color(0xff, 0xff, 0xff);  // Pure white
    color grey = color(0xc7, 0xb6, 0x4d);  // yellowish gray

    // Normalize the value to be between 0 and 1 for interpolation
    float value = mapCell.terrain;
    float normalizedValue = map(value, 0, 255, 0, 1);
  
    color c;
  
    // Determine the color based on the altitude value
    if (normalizedValue < 0.5) {
      // Scale the value to be between 0 and 1 within this subrange
      float scaledValue = map(normalizedValue, 0, 0.5, 0, 1);
      // Interpolate between brown and green
      c = lerpColor(brown, green, scaledValue);
    } else {
      // Scale the value to be between 0 and 1 within this subrange
      float scaledValue = map(normalizedValue, 0.5, 1, 0, 1);
      // Interpolate between green and white
      c = lerpColor(green, white, scaledValue);
    }
    
    float dt = constrain(mapCell.terrainOriginal - mapCell.terrain,0,3)/3.0;
    return lerpColor(c,grey,dt);
  }
  

  public void updateWaterColorMap() {
    waterColorMap.beginDraw();
    waterColorMap.noStroke();
    
    int i=0;
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        waterColorMap.set(x, y, waterColor(i));
        i++;
      }
    }
    waterColorMap.endDraw();
  }
  
  public void updateSedimentMap() {
    waterColorMap.beginDraw();
    waterColorMap.noStroke();
    
    int i=0;
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        float s = (map[i].water<=0) ? 0 : constrain(map[i].sediment/map[i].water*128,0,255);
        waterColorMap.set(x, y, color(s,s,s,64));
        i++;
      }
    }
    waterColorMap.endDraw();
  }
  
  
  color waterColor(int i) {
    var mapCell = map[i];
    
    var wa2 = map(mapCell.water*10,0,5,0,255);
    var s = map(mapCell.sediment,0,sedimentCapacityConstant,0,255);
    return color(0,s,255,wa2);
  }
  
  
  public void drawTerrainMap() {
    int i=0;
    int j=TERRAIN_WIDTH;
    for(int y=0;y<TERRAIN_HEIGHT-1;++y) {
      beginShape(TRIANGLE_STRIP);
      texture(terrainColorMap);
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
    //normal(mapCell.sx,mapCell.sy,-1);
    vertex( x, y, map[a].terrain, x, y );
  }
  
  
  public void drawWaterMap() {
    int i=0;
    int j=TERRAIN_WIDTH;
    for(int y=0;y<TERRAIN_HEIGHT-1;++y) {
      beginShape(TRIANGLE_STRIP);
      texture(waterColorMap);
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        waterPixel(x,y  ,i);
        waterPixel(x,y+1,j);
        i++;
        j++;
      }
      endShape();
    }
    assert(j==TERRAIN_SIZE);
  }
  
  
  public void waterPixel(int x,int y,int i) {
    vertex( x, y, effectiveHeight(i), x, y );
  }

 
  // terrain height at index.
  public float terrainLevel(int a) {
    return map[a].terrain;
  }
  
  
  // terrain height at x,y
  public float terrainLevel(int x,int y) {
    return terrainLevel(addr(x,y));
  }
  
  
  // water level (not including terrain height) 
  public float waterLevel(int a) {
    return map[a].water * waterDensityScale;
  }
  
  
  // water level at x,y
  public float waterLevel(int x,int y) {
    return waterLevel(addr(x,y));
  }
  
  
  // terrain height + water height
  public float effectiveHeight(int index) {
    return terrainLevel(index) + waterLevel(index);
  }
  
  
  // terrain height + water height at x,y
  public float effectiveHeight(int x,int y) {
    var a = addr(x,y);
    return effectiveHeight(a);
  }
  
   
  public float sedimentLevel(int x,int y) {
    return map[addr(x,y)].sediment;
  }
  

  public void report() {
    println("y,x,terrain,water,sediment,Flux 0,Flux 1,Flux 2,Flux 3,vx,vy,inFlow,outFlow,diff");
  
    for(int y=0;y<TERRAIN_HEIGHT;++y) {
      for(int x=0;x<TERRAIN_WIDTH;++x) {
        print(y+","+x+",");
        println(map[addr(x,y)]);
      }
    }
  }


  // If I ask for the flux from the north, I should get map[north].flux[south].
  // This should be true for all directions.
  float getFlux(int x,int y,int from,int to) {
    switch(from) {
      case 0: if(x>=TERRAIN_WIDTH-1) return 0;
      case 1: if(y<=0) return 0;
      case 2: if(x<=0) return 0;
      case 3: if(y>=TERRAIN_HEIGHT-1) return 0;
    }
    
    int adjacent = getDirectionIndex(x,y,from);
    return map[adjacent].flux[to];
  }
}
