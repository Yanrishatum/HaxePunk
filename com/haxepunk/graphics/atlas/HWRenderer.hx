package com.haxepunk.graphics.atlas;

import lime.graphics.GLRenderContext;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;
import openfl._internal.renderer.RenderSession;
import openfl._internal.renderer.opengl.GLRenderer;
import openfl._internal.renderer.opengl.GLBlendModeManager;
import openfl._internal.renderer.opengl.GLShaderManager;
import openfl._internal.renderer.opengl.GLMaskManager;
import openfl.display.BitmapData;
import openfl.display.Shader;
import openfl.geom.Rectangle;

/**
 * ...
 * @author 
 */
@:access(openfl.geom.ColorTransform)
@:access(openfl.geom.Matrix)
@:access(openfl.geom.Rectangle)
@:access(openfl.display.DisplayObject)

class HWRenderer
{
  private static inline var BPE:Int = Float32Array.BYTES_PER_ELEMENT;
  public static inline var INDEX_COUNT:Int = 6;
  public static inline var INDEX_STRIDE:Int = INDEX_COUNT * UInt16Array.BYTES_PER_ELEMENT;
  public static inline var VERTEX_COUNT:Int = 4;
  public static inline var BUFFER_EL_COUNT:Int = 8;
  public static inline var ATT_OFFSET_POSITION:Int = 0;
  public static inline var ATT_OFFSET_UV:Int = 2;
  public static inline var ATT_OFFSET_TINT:Int = 4;
  public static inline var STRIDE:Int = BUFFER_EL_COUNT * BPE;
  public static inline var ELEMENTS_PER_EXPAND:Int = 64;
  
  public static var onRender:Void->Void;
  
  public static function render(screen:HWScreen, renderSession:RenderSession):Void
  {
    if (screen.__worldAlpha <= 0 || screen.numStates == 0) return;
    
    var renderer:GLRenderer = cast(renderSession.renderer);
    var blendManager:GLBlendModeManager = cast(renderSession.blendModeManager);
    var shaderManager:GLShaderManager = cast(renderSession.shaderManager);
    var gl:GLRenderContext = renderSession.gl;
    
    var err:Int;
    inline function glErrCheck(name:String):Void
    {
      #if debug
      err = gl.getError();
      if (err != 0)
        trace("[" + name + "] " + err);
      #end
    }
    
    blendManager.setBlendMode(screen.__worldBlendMode);
		renderSession.filterManager.pushObject (screen);
		renderSession.maskManager.pushObject (screen);
    
		var rect = Rectangle.__pool.get ();
		rect.setTo (0, 0, screen.width, screen.height);
		renderSession.maskManager.pushRect (rect, screen.__renderTransform);
		
    //gl.blendEquation(gl.FUNC_ADD);
    //gl.blendFuncSeparate(gl.ONE, gl.ONE_MINUS_SRC_ALPHA, gl.SRC_ALPHA, gl.ZERO);
    
    var shader:Shader = shaderManager.initShader(screen.mainShader);
    
    var uMatrix:Array<Float> = renderer.getMatrix(screen.__renderTransform); // TODO: Optimize
    
    var useColorTransform:Bool = true;
    
    var states:Array<DrawState> = screen.states;
    var defaultShader:Shader = shader;
    
    screen.updateGLBuffers(gl);
    
    #if hp_postprocess
    gl.bindFramebuffer(gl.FRAMEBUFFER, screen.framebuffer);
    var c:Int = HXP.screen.color;
    gl.clearColor(((c & 0xff0000) >> 16) / 0xff, ((c & 0xff00) >> 8) /  0xff, (c & 0xff) / 0xff, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    #end
    
    // WTF OFL, why
    // TODO: Find a way to set this inside loop AND not crash video driver.
    gl.vertexAttribPointer(shader.data.aPosition.index, 2, gl.FLOAT, false, STRIDE, ATT_OFFSET_POSITION * BPE);
    gl.vertexAttribPointer(shader.data.aTexCoord.index, 2, gl.FLOAT, false, STRIDE, ATT_OFFSET_UV * BPE);
    gl.vertexAttribPointer(shader.data.aColor.index, 4, gl.FLOAT, false, STRIDE, ATT_OFFSET_TINT * BPE);
    
    var cacheShader:Shader = null;
    var cacheTexture:BitmapData = null, texture:BitmapData = null;
    var cacheBlend:Int = untyped screen.__worldBlendMode;
    var shaderDirty:Bool = true;
    var stateNum:Int = screen.numStates;
    
    for (i in 0...stateNum)
    {
      var state:DrawState = states[i];
      shader = state.shader;
      if (shader == null) shader = defaultShader;
      
      if (cacheBlend != state.blend)
      {
        cacheBlend = state.blend;
        blendManager.setBlendMode(cast state.blend);
      }
      
      //screen.bindGLBuffers(gl);
      
      texture = state.texture;
      if (shader != cacheShader)
      {
        shaderManager.setShader(shader);
        if (shader.data.uAlpha.value == null) shader.data.uAlpha.value = new Array<Float>();
        shader.data.uMatrix.value = uMatrix;
        shader.data.uAlpha.value[0] = screen.__worldAlpha;
        shader.data.uImage0.input = texture;
        
        //gl.vertexAttribPointer(shader.data.aPosition.index, 2, gl.FLOAT, false, STRIDE, ATT_OFFSET_POSITION * BPE);
        //gl.vertexAttribPointer(shader.data.aTexCoord.index, 2, gl.FLOAT, false, STRIDE, ATT_OFFSET_UV * BPE);
        //gl.vertexAttribPointer(shader.data.aColor.index, 4, gl.FLOAT, false, STRIDE, ATT_OFFSET_TINT * BPE);
        
        cacheShader = shader;
      }
      
      if (texture != cacheTexture)
      {
        shader.data.uImage0.input = texture;
        cacheTexture = texture;
      }
      
      shaderManager.updateShader(shader);
      
      gl.drawElements(gl.TRIANGLES, state.count, gl.UNSIGNED_SHORT, state.offset);
      
    }
    
    #if hp_postprocess
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    //gl.clearColor(0.0, 0.0, 0.0, 1.0);
    //gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    
    var shader:Shader = screen.postShader;
    shaderManager.setShader(shader);
    shader.data.uMatrix.value = uMatrix; // TODO: Proper alpha support
    shaderManager.updateShader(shader);
    
    gl.enable(gl.TEXTURE_2D);
    gl.bindTexture(gl.TEXTURE_2D, screen.postTexture);
    gl.uniform1i(shader.data.uImage0.index, 0);
    
    //gl.uniformMatrix4fv(shader.data.uMatrix.index, false, transMatrix);
    gl.enableVertexAttribArray(shader.data.aPosition.index);
    gl.enableVertexAttribArray(shader.data.aTexCoord.index);
    
    gl.bindBuffer(gl.ARRAY_BUFFER, screen.postVertices);
    gl.vertexAttribPointer(shader.data.aPosition.index, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 0);
    gl.vertexAttribPointer(shader.data.aTexCoord.index, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
    
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    
    #end
    shaderManager.setShader(null);
    
		renderSession.filterManager.popObject (screen);
		renderSession.maskManager.popRect ();
		renderSession.maskManager.popObject (screen);
    
		Rectangle.__pool.release (rect);
    
    // TODO: Used for screencapture, but have to find better solution.
    if (onRender != null)
    {
      gl.finish();
      onRender();
    }
  }
  
}