package com.haxepunk.graphics.atlas;
import com.haxepunk.Scene;
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import openfl.display.BitmapData;
import openfl.display.Tile;
import openfl.display.Tilemap;
import openfl.display.TilemapLayer;
import openfl.display.Tileset;
//import openfl.display.Tilesheet;

class DrawState
{
	private static var pool:DrawState;
	
	private static var drawHead:DrawState;
	private static var drawTail:DrawState;
  
	private static function getState(texture:BitmapData, smooth:Bool, blend:Int):DrawState
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
		
		state.set(texture, smooth, blend);
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
	
	public static function getDrawState(texture:BitmapData, smooth:Bool, blend:Int):DrawState
	{
		var state:DrawState = null;
		if (drawTail != null)
		{
			if (drawTail.texture == texture && drawTail.smooth == smooth && drawTail.blend == blend)
			{
				return drawTail;
			}
			else
			{
				state = getState(texture, smooth, blend);
				drawTail.next = state;
				drawTail = state;
			}
		}
		else
		{
			state = getState(texture, smooth, blend);
			drawTail = drawHead = state;
		}
    
    return state;
	}
	
	public var smooth:Bool = false;
	public var blend:Int = AtlasData.BLEND_NONE;
	
	public var next:DrawState;
  
  private var batcher:TilemapLayer;
  
  /** Buffer for this DrawState */
  public var buffer:Float32Array;
  public var glBuffer:GLBuffer;
  /** Amount of sprites */
  public var count:Int = 0;
	public var dataIndex:Int = 0;
  public var texture:BitmapData;
	
	public function new() 
	{
    
	}
  
  public function ensureElement():Void
  {
    if (buffer == null) buffer = new Float32Array(HardwareRenderer.TILE_SIZE * HardwareRenderer.MINIMUM_TILE_COUNT_PER_BUFFER);
    else if (buffer.length < count * HardwareRenderer.TILE_SIZE + HardwareRenderer.TILE_SIZE)
    {
      var oldBufferData = buffer; // TODO: Improve?
      buffer = new Float32Array(count * HardwareRenderer.TILE_SIZE + HardwareRenderer.TILE_SIZE);
      var i:Int = 0;
      while (i < oldBufferData.length)
      {
        buffer[i] = oldBufferData[i];
        i++;
      }
    }
  }
	
	public inline function reset():Void
	{
		dataIndex = 0;
    count = 0;
    texture = null;
		next = null;
		DrawState.putState(this);
	}
	
	public inline function set(texture:BitmapData, smooth:Bool, blend:Int):Void
	{
		this.texture = texture;
		this.smooth = smooth;
		this.blend = blend;
	}
  
	public inline function render(scene:Scene):Void
	{
    scene.tilemap.drawTiles(this);
	}
}