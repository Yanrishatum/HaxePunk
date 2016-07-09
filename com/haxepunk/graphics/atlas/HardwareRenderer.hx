package com.haxepunk.graphics.atlas;
import lime.graphics.GLRenderContext;
import lime.utils.Float32Array;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl._internal.renderer.RenderSession;
import openfl._internal.renderer.opengl.GLRenderer;
import openfl.display.Shader;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

/**
 * ...
 * @author Yanrishatum
 */
class HardwareRenderer extends DisplayObject
{
  
  public static inline var TILE_SIZE:Int = 48;
  public static inline var MINIMUM_TILE_COUNT_PER_BUFFER:Int = 10;
  private static var shader:TileShader;
  
  private var states:Array<DrawState>;
  private var stateTextures:Array<BitmapData>;
  private var stateCoutns:Array<Int>;
  private var stateNum:Int;
  
  public function new ()
  {
    super();
    if (shader == null) shader = new TileShader();
    states = new Array();
    stateTextures = new Array();
    stateCoutns = new Array();
    stateNum = 0;
  }
  
  @:access(openfl.geom.Rectangle)
  override function __getBounds(rect:Rectangle, matrix:Matrix):Void 
  {
		var bounds:Rectangle = Rectangle.__temp;
		bounds.setTo (0, 0, HXP.width, HXP.height);
		bounds.__transform (bounds, matrix);
    rect.__expand(bounds.x, bounds.y, bounds.width, bounds.height);
    trace("BOUNDS", rect);
  }
  
  override function get_width():Float 
  {
    return HXP.width;
  }
  
  override function set_width(value:Float):Float 
  {
    return HXP.width;
  }
  
  override function get_height():Float 
  {
    return HXP.height;
  }
  
  override function set_height(value:Float):Float 
  {
    return HXP.height;
  }
  
  //override function __hitTest(x:Float, y:Float, shapeFlag:Bool, stack:Array<DisplayObject>, interactiveOnly:Bool, hitObject:DisplayObject):Bool 
  //{
    //trace("HIT_TEST");
    //return true;
    ////return super.__hitTest(x, y, shapeFlag, stack, interactiveOnly, hitObject);
  //}
  
  public function clear():Void
  {
    stateNum = 0;
    //__setRenderDirty();
  }
  
  public function drawTiles(state:DrawState):Void
  {
    states[stateNum] =  state;
    stateCoutns[stateNum] = state.count;
    stateTextures[stateNum] = state.texture;
    stateNum++;
  }
  
  override public function __renderGL(renderSession:RenderSession):Void 
  {
    var gl:GLRenderContext = renderSession.gl;
    var renderer:GLRenderer = cast renderSession.renderer;
    
    renderSession.shaderManager.setShader(shader);
    gl.uniform1f(shader.data.uAlpha.index, this.__worldAlpha);
    gl.uniformMatrix4fv(shader.data.uMatrix.index, false, renderer.getMatrix(this.__worldTransform));
    //gl.uniformMatrix4fv (shader.data.uMatrix.index, false, renderer.getMatrix (tilemap.__worldTransform));
    
    var blend:Int = -1;
    var texture:BitmapData = null;
    
    var i:Int = 0;
    var offset:Int;
    while (i < stateNum)
    {
      var state:DrawState = states[i];
      
      if (blend != state.blend)
      {
        renderSession.blendModeManager.setBlendMode(cast (state.blend)); // BlendMode is Int abstract, should work?
        blend = state.blend;
      }
      
      if (texture != stateTextures[i])
      {
        texture = stateTextures[i];
        gl.bindTexture (gl.TEXTURE_2D, texture.getTexture (gl));
      }
      
      if (state.glBuffer == null) state.glBuffer = gl.createBuffer();
			gl.bindBuffer(gl.ARRAY_BUFFER, state.glBuffer);
      
      gl.bufferData(gl.ARRAY_BUFFER, state.buffer, gl.DYNAMIC_DRAW);
      
      gl.vertexAttribPointer(shader.data.aPosition.index, 2, gl.FLOAT, false, 8 * Float32Array.BYTES_PER_ELEMENT, 0);
      gl.vertexAttribPointer(shader.data.aTexCoord.index, 2, gl.FLOAT, false, 8 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
      gl.vertexAttribPointer(shader.data.aColor.index, 4, gl.FLOAT, false, 8 * Float32Array.BYTES_PER_ELEMENT, 4 * Float32Array.BYTES_PER_ELEMENT);
      
      gl.drawArrays(gl.TRIANGLES, 0, stateCoutns[i] * 6);
      
      i++;
    }
    /*
		renderSession.blendModeManager.setBlendMode (tilemap.blendMode);
		renderSession.shaderManager.setShader (shader);
		renderSession.maskManager.pushObject (tilemap);
		
		var renderer:GLRenderer = cast renderSession.renderer;
		
		gl.uniform1f (shader.data.uAlpha.index, tilemap.__worldAlpha);
		gl.uniformMatrix4fv (shader.data.uMatrix.index, false, renderer.getMatrix (tilemap.__worldTransform));
		
		var tiles, count, bufferData, buffer, previousLength, offset, uvs, uv;
		var cacheTileID = -1, tileWidth = 0, tileHeight = 0;
		var tile, tileMatrix, x, y, x2, y2, x3, y3, x4, y4;
		
		for (layer in tilemap.__layers) {
			
			if (layer.__tiles.length == 0 || layer.tileset == null || layer.tileset.bitmapData == null) continue;
			
			gl.bindTexture (gl.TEXTURE_2D, layer.tileset.bitmapData.getTexture (gl));
			
			tiles = layer.__tiles;
			count = tiles.length;
			uvs = layer.tileset.__uvs;
			
			bufferData = layer.__bufferData;
			
			if (bufferData == null || bufferData.length != count * 24) {
				
				previousLength = 0;
				
				if (bufferData == null) {
					
					bufferData = new Float32Array (count * 24);
					
				} else {
					
					previousLength = Std.int (bufferData.length / 24);
					
					var data = new Float32Array (count * 24);
					
					for (i in 0...bufferData.length) {
						
						data[i] = bufferData[i];
						
					}
					
					bufferData = data;
					
				}
				
				for (i in previousLength...count) {
					
					updateTileUV(tiles[i], uvs, i * 24, bufferData);
					
				}
				
				layer.__bufferData = bufferData;
				
			}
			
			if (layer.__buffer == null) {
				
				layer.__buffer = gl.createBuffer ();
				
			}
			
			gl.bindBuffer (gl.ARRAY_BUFFER, layer.__buffer);
			
			for (i in 0...count) {
				
				tile = tiles[i];
				
				if (tile.id != cacheTileID) {
					
					tileWidth = Std.int (layer.tileset.__rects[tile.id].width);
					tileHeight = Std.int (layer.tileset.__rects[tile.id].height);
					cacheTileID = tile.id;
					
				}
				
				offset = i * 24;
				
				if (tile.__dirtyUV) {
					
					updateTileUV(tile, uvs, offset, bufferData);
					
				}
				
				if (tile.__dirtyTranform) {
					
					tileMatrix = tile.matrix;
					
					x = tile.__transform[0] = tileMatrix.__transformX (0, 0);
					y = tile.__transform[1] = tileMatrix.__transformY (0, 0);
					x2 = tile.__transform[2] = tileMatrix.__transformX (tileWidth, 0);
					y2 = tile.__transform[3] = tileMatrix.__transformY (tileWidth, 0);
					x3 = tile.__transform[4] = tileMatrix.__transformX (0, tileHeight);
					y3 = tile.__transform[5] = tileMatrix.__transformY (0, tileHeight);
					x4 = tile.__transform[6] = tileMatrix.__transformX (tileWidth, tileHeight);
					y4 = tile.__transform[7] = tileMatrix.__transformY (tileWidth, tileHeight);
					
					tile.__dirtyTranform = false;
					
				} else {
					
					x = tile.__transform[0];
					y = tile.__transform[1];
					x2 = tile.__transform[2];
					y2 = tile.__transform[3];
					x3 = tile.__transform[4];
					y3 = tile.__transform[5];
					x4 = tile.__transform[6];
					y4 = tile.__transform[7];
					
				}
				
				bufferData[offset + 0] = x;
				bufferData[offset + 1] = y;
				bufferData[offset + 4] = x2;
				bufferData[offset + 5] = y2;
				bufferData[offset + 8] = x3;
				bufferData[offset + 9] = y3;
				
				bufferData[offset + 12] = x3;
				bufferData[offset + 13] = y3;
				bufferData[offset + 16] = x2;
				bufferData[offset + 17] = y2;
				bufferData[offset + 20] = x4;
				bufferData[offset + 21] = y4;
				
			}
			
			gl.bufferData (gl.ARRAY_BUFFER, bufferData, gl.DYNAMIC_DRAW);
			
			gl.vertexAttribPointer (shader.data.aPosition.index, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 0);
			gl.vertexAttribPointer (shader.data.aTexCoord.index, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
			
			gl.drawArrays (gl.TRIANGLES, 0, tiles.length * 6);
			
		}
		
		renderSession.maskManager.popObject (tilemap);
		*/
  }
  
  
}