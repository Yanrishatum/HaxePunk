package com.haxepunk.graphics.atlas;
import com.haxepunk.Scene;
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt32Array;
import openfl.display.BitmapData;
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
  
	private static function getState(data:AtlasData, texture:BitmapData, smooth:Bool, blend:Int):DrawState
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
		
		state.set(data, texture, smooth, blend);
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
      state.reset();
		}
    
		drawHead = null;
		drawTail = null;
	}
	
	public static function getDrawState(data:AtlasData, texture:BitmapData, smooth:Bool, blend:Int):DrawState
	{
		var state:DrawState = null;
		if (drawTail != null)
		{
			if (drawTail.data == data && drawTail.texture == texture && drawTail.smooth == smooth && drawTail.blend == blend)
			{
				return drawTail;
			}
			else
			{
				state = getState(data, texture, smooth, blend);
				drawTail.next = state;
				drawTail = state;
			}
		}
		else
		{
			state = getState(data, texture, smooth, blend);
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
  public var data:AtlasData;
  
	public function new() 
	{
    
	}
  
	public inline function reset():Void
	{
		offset = 0;
    count = 0;
    texture = null;
    data = null;
		next = null;
		DrawState.putState(this);
	}
	
	public inline function set(data:AtlasData, texture:BitmapData, smooth:Bool, blend:Int):Void
	{
    this.data = data;
		this.texture = texture;
		this.smooth = smooth;
		this.blend = blend;
    this.offset = data.bufferOffset;
	}
  
	public inline function render(scene:Scene):Void
	{
    //trace(offset, count, offset + count, data.bufferSize);
    //if (offset + count >= data.bufferSize) throw "INVALID DATA";
    scene.tilemap.drawTiles(this);
	}
}