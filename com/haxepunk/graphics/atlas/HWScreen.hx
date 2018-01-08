package com.haxepunk.graphics.atlas;
import format.swf.Data.BlendMode;
import lime.graphics.GLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLFramebuffer;
import lime.graphics.opengl.GLRenderbuffer;
import lime.graphics.opengl.GLTexture;
import lime.utils.Float32Array;
import lime.utils.UInt16Array;
import openfl.Lib;
import openfl._internal.renderer.RenderSession;
import openfl._internal.renderer.opengl.GLDisplayObject;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.Graphics;
import openfl.display.Shader;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

/**
 * ...
 * @author 
 */
class HWScreen extends DisplayObject
{
  public var numStates:Int;
  public var states:Array<DrawState>;
  public var mainShader:Shader;
  
  private var ctx:GLRenderContext;
  public var vertexBuffer:GLBuffer;
  public var indexBuffer:GLBuffer;
  private var _bufferDirty:Bool;
  
  private var quadCount:Int;
  public var quadFilled:Int;
  public var vertex:Float32Array;
  public var index:UInt16Array;
  
  #if hp_postprocess
  public var framebuffer:GLFramebuffer;
  public var postTexture:GLTexture;
  public var postRenderbuffer:GLRenderbuffer;
  public var postVertices:GLBuffer;
  public var framebufferInvalid:Bool;
  private var _framebufferWidth:Int;
  private var _framebufferHeight:Int;
  public var postShader:Shader;
  #end
  
  public function new() 
  {
    super();
    #if hp_gles2
    mainShader = new LegacyTileShader();
    #else
    mainShader = new TileShader();
    #end
    states = new Array();
    vertex = new Float32Array(HWRenderer.BUFFER_EL_COUNT * HWRenderer.VERTEX_COUNT * HWRenderer.ELEMENTS_PER_EXPAND);
    index = new UInt16Array(HWRenderer.INDEX_COUNT * HWRenderer.ELEMENTS_PER_EXPAND);
    quadCount = HWRenderer.ELEMENTS_PER_EXPAND;
    quadFilled = 0;
    fillIndex();
    
    #if hp_postprocess
    postShader = new PostprocessShader();
    #end
  }
  
  #if hp_postprocess
  
  private function initFramebuffer(gl:GLRenderContext):Void
  {
    var w:Int = Lib.current.stage.stageWidth;
    var h:Int = Lib.current.stage.stageHeight;
    // Init texture
    gl.activeTexture(gl.TEXTURE0);
    postTexture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, postTexture);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, 0); // null
    gl.bindTexture(gl.TEXTURE_2D, null);
    
    // Init renderbuffer
    postRenderbuffer = gl.createRenderbuffer();
    gl.bindRenderbuffer(gl.RENDERBUFFER, postRenderbuffer);
    gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, w, h);
    gl.bindRenderbuffer(gl.RENDERBUFFER, null);
    
    framebuffer = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, postTexture, 0);
    gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, postRenderbuffer);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    
    postVertices = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, postVertices);
    var verts = new Float32Array([
      -1.0, -1.0, 0, 0,
			 1.0, -1.0, 1, 0,
			-1.0,  1.0, 0, 1,
			 1.0, -1.0, 1, 0,
			 1.0,  1.0, 1, 1,
			-1.0,  1.0, 0, 1]);
    gl.bufferData(gl.ARRAY_BUFFER, verts.byteLength, verts, gl.STATIC_DRAW);
    gl.bindBuffer(gl.ARRAY_BUFFER, postVertices);
    
    _framebufferWidth = w;
    _framebufferHeight = h;
    framebufferInvalid = false;
  }
  
  public function resize(gl:GLRenderContext):Void
  {
    var w:Int = Lib.current.stage.stageWidth;
    var h:Int = Lib.current.stage.stageHeight;
    gl.bindTexture(gl.TEXTURE_2D, postTexture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, 0); // null
    gl.bindTexture(gl.TEXTURE_2D, null);
    
    gl.bindRenderbuffer(gl.RENDERBUFFER, postRenderbuffer);
    gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, w, h);
    gl.bindRenderbuffer(gl.RENDERBUFFER, null);
    _framebufferWidth = w;
    _framebufferHeight = h;
    framebufferInvalid = false;
  }
  
  public function invalidate():Void
  {
    framebufferInvalid = _framebufferWidth != Lib.current.stage.stageWidth || _framebufferHeight != Lib.current.stage.stageHeight;// true;
  }
  
  override function __cleanup():Void 
  {
    super.__cleanup();
    ctx.deleteRenderbuffer(postRenderbuffer);
    ctx.deleteTexture(postTexture);
    ctx.deleteFramebuffer(framebuffer);
    ctx.deleteBuffer(postVertices);
  }

  #end
  
  public function clear():Void
  {
    quadFilled = 0;
    for (i in 0...numStates) states[i].reset();
    numStates = 0;
    
  }
  
  private inline function ensureElement():Void
  {
    if (quadFilled == quadCount)
    {
      //trace('Ensure: Quad refill $quadCount -> ${quadCount + HWRenderer.ELEMENTS_PER_EXPAND}');
      quadCount += HWRenderer.ELEMENTS_PER_EXPAND;
      var tmpVert:Float32Array = new Float32Array(quadCount * HWRenderer.VERTEX_COUNT * HWRenderer.BUFFER_EL_COUNT);
      tmpVert.set(vertex, 0);
      vertex = tmpVert;
      var tmpIndex:UInt16Array = new UInt16Array(quadCount * HWRenderer.INDEX_COUNT);
      tmpIndex.set(index, 0);
      index = tmpIndex;
      fillIndex();
    }
  }
  
  private inline function fillIndex():Void
  {
    var i:Int = quadFilled * HWRenderer.INDEX_COUNT;
    var vertexOffset:Int = quadFilled * HWRenderer.VERTEX_COUNT;
    var len:Int = quadCount * HWRenderer.INDEX_COUNT;
    while (i < len)
    {
      index[i    ] = vertexOffset;//0
      index[i + 1] = vertexOffset + 1;
      index[i + 2] = vertexOffset + 2;
      index[i + 3] = vertexOffset + 2;
      index[i + 4] = vertexOffset + 1;
      index[i + 5] = vertexOffset + 3;
      vertexOffset += HWRenderer.VERTEX_COUNT;
      i += HWRenderer.INDEX_COUNT;
    }
    _bufferDirty = true;
  }
  
  public function drawTile(texture:BitmapData, rect:Rectangle,
    tx:Float, ty:Float, a:Float, b:Float, c:Float, d:Float,
    red:Float, green:Float, blue:Float, alpha:Float, blend:Int, shader:Shader, smooth:Bool):Void
  {
    if (rect.width == 0 || rect.height == 0) return; // No point rendering what is invisible.
    ensureElement();
    var state:DrawState = DrawState.getDrawState(this, texture, smooth, blend, shader);
    
    var data:Float32Array = vertex;
    var dataIndex:Int = quadFilled * HWRenderer.BUFFER_EL_COUNT * HWRenderer.VERTEX_COUNT;
    //trace(quadFilled, quadCount, dataIndex);
    // UV
    #if hp_gles2
    var uvx:Float = rect.x / texture.width;
    var uvy:Float = rect.y / texture.height;
    var uvx2:Float = rect.right / texture.width;
    var uvy2:Float = rect.bottom / texture.height;
    #else
    var uvx:Float = rect.x;
    var uvy:Float = rect.y;
    var uvx2:Float = rect.right;
    var uvy2:Float = rect.bottom;
    #end
    
    // TODO: Replace inline with macro, because I don't trust Haxe to properly inline that and not do shit like var v = ,,,; { inline block that uses v arg }
    // Position
    #if hp_round_coords
    inline function round(v:Float):Float return Math.fround(v);
    #else
    inline function round(v:Float):Float return v;
    #end
    
    var x24:Float = a * rect.width + tx;
    var y24:Float = b * rect.width + ty;
    
    if (alpha < 0) alpha = 0;
    else if (alpha > 1) alpha = 1; // Clip out alpha values.
    
    inline function fillTint():Void
    {
      data[dataIndex++] = red;
      data[dataIndex++] = green;
      data[dataIndex++] = blue;
      data[dataIndex++] = alpha;
    }
    
    // TODO: Find a way to use tint only once. I don't like sending tinting data 4 times.
    
    // top-left
    data[dataIndex++] = round(tx);
    data[dataIndex++] = round(ty);
    data[dataIndex++] = uvx;
    data[dataIndex++] = uvy;
    fillTint();
    // top-right
    data[dataIndex++] = round(x24);
    data[dataIndex++] = round(y24);
    data[dataIndex++] = uvx2;
    data[dataIndex++] = uvy;
    fillTint();
    // bottom-left
    data[dataIndex++] = round(c * rect.height + tx);
    data[dataIndex++] = round(d * rect.height + ty);
    data[dataIndex++] = uvx;
    data[dataIndex++] = uvy2;
    fillTint();
    
    //// bottom-left
    //data[dataIndex++] = round(c * rect.height + tx);
    //data[dataIndex++] = round(d * rect.height + ty);
    //data[dataIndex++] = uvx;
    //data[dataIndex++] = uvy2;
    //fillTint();
    //// top-right
    //data[dataIndex++] = round(x24);
    //data[dataIndex++] = round(y24);
    //data[dataIndex++] = uvx2;
    //data[dataIndex++] = uvy;
    //fillTint();
    
    // bottom-right
    data[dataIndex++] = round(x24 + c * rect.height);
    data[dataIndex++] = round(y24 + d * rect.height);
    data[dataIndex++] = uvx2;
    data[dataIndex++] = uvy2;
    fillTint();
    
    quadFilled++;
    state.count += HWRenderer.INDEX_COUNT;
  }
  
  public function updateGLBuffers(gl:GLRenderContext):Void
  {
    if (gl != ctx)
    {
      ctx = gl;
      vertexBuffer = gl.createBuffer();
      indexBuffer = gl.createBuffer();
      _bufferDirty = true;
      initFramebuffer(gl);
      //invalidate(); // TODO: Handle context loss
    }
    
    if (framebufferInvalid) resize(gl);
    
    // TODO: Dirty check for vertex? It pretty much always dirty, anyway.
    
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
    if (_bufferDirty)
    {
      gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, index.byteLength, index, gl.DYNAMIC_DRAW);
      _bufferDirty = false;
    }
    
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, vertex.byteLength, vertex, gl.DYNAMIC_DRAW);
  }
  
  public inline function bindGLBuffers(gl:GLRenderContext):Void
  {
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
  }
  
  @:access(openfl.geom.Rectangle)
  private override function __getBounds (rect:Rectangle, matrix:Matrix):Void
  {
    var bounds:Rectangle = Rectangle.__pool.get();
    bounds.setTo(0, 0, HXP.width * HXP.screen.fullScaleX, HXP.height * HXP.screen.fullScaleY);
    bounds.__transform (bounds, matrix);
    rect.__expand (bounds.x, bounds.y, bounds.width, bounds.height);
    Rectangle.__pool.release (bounds);
  }
  
  override public function __update(transformOnly:Bool, updateChildren:Bool, ?maskGraphics:Graphics = null):Void 
  {
    #if !hp_disable_autoscaling
    // TODO: Update only when have to.
    scaleX = HXP.screen.fullScaleX;
    scaleY = HXP.screen.fullScaleY;
    #end
    
    super.__update(transformOnly, updateChildren, maskGraphics);
  }
  
  override function __renderGL(renderSession:RenderSession):Void 
  {
		__updateCacheBitmap (renderSession, false);
		
		if (__cacheBitmap != null && !__cacheBitmapRender) {
			
			openfl._internal.renderer.opengl.GLBitmap.render (__cacheBitmap, renderSession);
			
		} else {
      //super.__renderGL(renderSession);
      GLDisplayObject.render (this, renderSession);
      HWRenderer.render(this, renderSession);
    }
  }
  
  override function get_width():Float 
  {
    return HXP.width * HXP.screen.fullScaleX;
  }
  
  override function get_height():Float 
  {
    return HXP.height * HXP.screen.fullScaleY;
  }
  
  
}