package com.haxepunk.graphics.atlas;
import lime.graphics.GLRenderContext;
import lime.utils.Float32Array;
import lime.utils.UInt32Array;
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
  
  //public static inline var TILE_SIZE:Int = 48;
  public static inline var TILE_SIZE:Int = 8 * 4;
  public static inline var MINIMUM_TILE_COUNT_PER_BUFFER:Int = 10;
  
  public static var onRender:Void->Void;
  private static var renderShader:TileShader;
  
  private var states:Array<DrawState>;
  private var stateTextures:Array<BitmapData>;
  private var stateBuffers:Array<AtlasData>;
  private var stateCoutns:Array<Int>;
  private var stateOffsets:Array<Int>;
  private var stateNum:Int;
  private var transMatrix:Float32Array;
  
  public function new ()
  {
    super();
    transMatrix = new Float32Array(16);
    if (renderShader == null) renderShader = new TileShader();
    states = new Array();
    stateTextures = new Array();
    stateBuffers = new Array();
    stateCoutns = new Array();
    stateOffsets = new Array();
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
    stateCoutns[stateNum] = state.count * 6;
    stateTextures[stateNum] = state.texture;
    stateBuffers[stateNum] = state.data;
    stateOffsets[stateNum] = state.offset * 6 * 2;
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
    
    var i:Int = 0;
    var m:Array<Float> = renderer.getMatrix(this.__worldTransform);
    #if !hp_disable_autoscaling
    scaleX = HXP.screen.fullScaleY;
    scaleY = HXP.screen.fullScaleY;
    #end
    while (i < 16)
    {
      transMatrix[i] = m[i];
      i++;
    }
    renderSession.shaderManager.setShader(renderShader);
    //gl.enable(gl.BLEND);
    //renderSession.blendModeManager.setBlendMode(cast 10);
    gl.blendEquation(gl.FUNC_ADD);
    gl.blendFuncSeparate(gl.ONE, gl.ONE_MINUS_SRC_ALPHA, gl.SRC_ALPHA, gl.ZERO);
    gl.uniform1f(renderShader.data.uAlpha.index, this.__worldAlpha);
    gl.uniformMatrix4fv(renderShader.data.uMatrix.index, false, transMatrix);
    //gl.uniformMatrix4fv (shader.data.uMatrix.index, false, renderer.getMatrix (tilemap.__worldTransform));
    
    var blend:Int = 10;
    var texture:BitmapData = null;
    i = 0;
    var offset:Int;
    while (i < stateNum)
    {
      var state:DrawState = states[i];
      var data:AtlasData = stateBuffers[i];
      
      if (blend != state.blend)
      {
        renderSession.blendModeManager.setBlendMode(cast (state.blend)); // BlendMode is Int abstract, should work?
        blend = state.blend;
        //if (blend != 10) trace(blend);
      }
      
      if (texture != stateTextures[i])
      {
        texture = stateTextures[i];
        gl.bindTexture (gl.TEXTURE_2D, texture.getTexture (gl));
      }
      
      if (data.glBuffer == null)
      {
        data.glBuffer = gl.createBuffer();
        data.glIndexes = gl.createBuffer();
      }
      
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, data.glIndexes);
      if (data.indexBufferDirty)
      {
        data.indexBufferDirty = false;
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, data.indexes, gl.DYNAMIC_DRAW);
      }
      
			gl.bindBuffer(gl.ARRAY_BUFFER, data.glBuffer);
      if (data.vertexBufferDirty)
      {
        data.vertexBufferDirty = false;
        gl.bufferData(gl.ARRAY_BUFFER, data.buffer, gl.DYNAMIC_DRAW);
      }
      
      gl.vertexAttribPointer(renderShader.data.aPosition.index, 2, gl.FLOAT, false, 8 * Float32Array.BYTES_PER_ELEMENT, 0);
      gl.vertexAttribPointer(renderShader.data.aTexCoord.index, 2, gl.FLOAT, false, 8 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
      gl.vertexAttribPointer(renderShader.data.aColor.index, 4, gl.FLOAT, false, 8 * Float32Array.BYTES_PER_ELEMENT, 4 * Float32Array.BYTES_PER_ELEMENT);
      
      gl.drawElements(gl.TRIANGLES, stateCoutns[i], gl.UNSIGNED_SHORT, stateOffsets[i]);
      
      i++;
    }
    if (onRender != null)
    {
      gl.finish();
      onRender();
    }
    #end
  }
  
  
}