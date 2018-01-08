package com.haxepunk.graphics.atlas;
import com.haxepunk.Scene;
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt32Array;
import openfl.display.BitmapData;
import openfl.display.Shader;
import openfl.display.Tile;
import openfl.display.Tilemap;
//import openfl.display.TilemapLayer;
import openfl.display.Tileset;
//import openfl.display.Tilesheet;

class DrawState
{
	private static var pool:DrawState;
	
	private static var drawHead:DrawState;
	private static var drawTail:DrawState;
  
	private static function getState(screen:HWScreen, texture:BitmapData, smooth:Bool, blend:Int, shader:Shader):DrawState
	{
		var state:DrawState = null;
		
		if (pool != null)
		{
			state = pool;
			pool = state.next;
      state.next = null;
		}
		else
		{
			state = new DrawState();
		}
		
		state.set(screen.quadFilled, texture, smooth, blend, shader);
    screen.states[screen.numStates++] = state;
		return state;
	}
	
	private static function putState(state:DrawState):Void
	{
		if (pool != null)
		{
			state.next = pool;
			pool = state;
		}
		else
		{
			pool = state;
		}
	}
	
	public static function drawStates(scene:Scene):Void
	{
		var next:DrawState = drawHead;
		var state:DrawState;
		
    while (next != null)
		{
			state = next;
			next = state.next;
      state.render(scene);
      //state.reset();
      DrawState.putState(state);
		}
    
		drawHead = null;
		drawTail = null;
	}
	
	public static function getDrawState(screen:HWScreen, texture:BitmapData, smooth:Bool, blend:Int, shader:Shader):DrawState
	{
		var state:DrawState = null;
		if (drawTail != null)
		{
			if (drawTail.texture == texture && drawTail.smooth == smooth && drawTail.blend == blend && drawTail.shader == shader)
			{
				return drawTail;
			}
			else
			{
				state = getState(screen, texture, smooth, blend, shader);
				drawTail.next = state;
				drawTail = state;
			}
		}
		else
		{
			state = getState(screen, texture, smooth, blend, shader);
			drawTail = drawHead = state;
		}
    
    return state;
	}
	
	public var smooth:Bool = false;
	public var blend:Int = AtlasData.BLEND_NONE;
	
	public var next:DrawState;
  
  //private var batcher:TilemapLayer;
  
  /** Amount of sprites */
  public var count:Int = 0;
	public var offset:Int = 0;
  public var texture:BitmapData;
  
  public var shader:Shader;
  
	public function new() 
	{
    
	}
  
	public inline function reset():Void
	{
		offset = 0;
    count = 0;
    texture = null;
		next = null;
    shader = null;
    
		DrawState.putState(this);
	}
  
	public inline function set(offset:Int, texture:BitmapData, smooth:Bool, blend:Int, shader:Shader):Void
	{
		this.texture = texture;
		this.smooth = smooth;
		this.blend = blend;
    this.offset = offset * HWRenderer.INDEX_STRIDE;
    this.shader = shader;
	}
  
	public inline function render(scene:Scene):Void
	{
    //trace(offset, count, offset + count, data.bufferSize);
    //if (offset + count >= data.bufferSize) throw "INVALID DATA";
    
    // HardwareRenderer
    //scene.tilemap.drawTiles(this);
	}
}