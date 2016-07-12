package com.haxepunk.graphics.atlas;
import lime.graphics.GLRenderContext;
import lime.utils.Float32Array;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.DisplayObject;
import openfl.display.Shader;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
#if !display
import openfl._internal.renderer.RenderSession;
import openfl._internal.renderer.opengl.GLRenderer;
#end

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
  
  #if !display
  // Disabled for display, because OFL uses Very Awesome Way To Hide Internals, which breaks autocomplete.
  @:access(openfl.geom.Rectangle)
  override function __getBounds(rect:Rectangle, matrix:Matrix):Void 
  {
		var bounds:Rectangle = Rectangle.__temp;
		bounds.setTo (0, 0, HXP.width, HXP.height);
		bounds.__transform (bounds, matrix);
    rect.__expand(bounds.x, bounds.y, bounds.width, bounds.height);
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
    #end
  }
  
  
}