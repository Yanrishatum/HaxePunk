package com.haxepunk.graphics.atlas;

import com.haxepunk.Scene;
import com.haxepunk.ds.Either;
import flash.display.BitmapData;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.geom.Rectangle;
import flash.geom.Point;
import lime.graphics.opengl.GLBuffer;
import lime.utils.Float32Array;
import lime.utils.UInt32Array;
import openfl.display.BlendMode;
import openfl.geom.Matrix;
import openfl.display.Tile;
import openfl.display.Tileset;
//import openfl.display.Tilesheet;

/**
 * Abstract representing either a `String`, a `AtlasData` or a `BitmapData`.
 * 
 * Conversion is automatic, no need to use this.
 */
#if display
typedef AtlasDataType = Dynamic;
#else
abstract AtlasDataType(AtlasData)
{
	private inline function new(data:AtlasData) this = data;
	@:dox(hide) @:to public inline function toAtlasData():AtlasData return this;

	@:dox(hide) @:from public static inline function fromString(s:String) {
		return new AtlasDataType(AtlasData.getAtlasDataByName(s, true));
	}
	@:dox(hide) @:from public static inline function fromBitmapData(bd:BitmapData) {
		return new AtlasDataType(new AtlasData(bd));
	}
	@:dox(hide) @:from public static inline function fromAtlasData(data:AtlasData) {
		return new AtlasDataType(data);
	}
}
#end

class AtlasData
{

	public var width(default, null):Int;
	public var height(default, null):Int;
	
	public var isRGB:Bool;
	public var isAlpha:Bool;
  
	public static inline var BLEND_NONE:Int = BLEND_NORMAL;
	public static inline var BLEND_ADD:Int = 0;
	public static inline var BLEND_NORMAL:Int = 10;
	public static inline var BLEND_MULTIPLY:Int = 9;
	public static inline var BLEND_SCREEN:Int = 12;

  public var buffer:Float32Array;
  public var indexes:UInt32Array;
  public var glBuffer:GLBuffer;
  public var glIndexes:GLBuffer;
  
  public var indexBufferDirty:Bool;
  public var vertexBufferDirty:Bool;
  
  /** Current amount of filled data in tiles. */
  public var bufferOffset:Int;
  /** Overall buffer size */
  public var bufferSize:Int;
  
	/**
	 * Creates a new AtlasData class
	 * 
	 * **NOTE**: Only create one instace of AtlasData per name. An error will be thrown if you try to create a duplicate.
	 * 
	 * @param bd     BitmapData image to use for rendering
	 * @param name   A reference to the image data, used with destroy and for setting rendering flags
	 */
	public function new(bd:BitmapData, ?name:String, ?flags:Int)
	{
		_texture = bd;
		_name = name;

		if(_name != null)
		{
			if (_dataPool.exists(_name))
			{
				throw 'Cannot cache duplicate AtlasData with the name "$_name"';
			}
			else
			{
				_dataPool.set(_name, this);
			}
		}
    _atlases.push(this);

		isAlpha = true;
		isRGB = true;

		width = bd.width;
		height = bd.height;
	}
  
  private function ensureElement():Void
  {
    if (buffer == null)
    {
      bufferSize = HardwareRenderer.MINIMUM_TILE_COUNT_PER_BUFFER;
      buffer = new Float32Array(HardwareRenderer.MINIMUM_TILE_COUNT_PER_BUFFER * HardwareRenderer.TILE_SIZE);
      indexes = new UInt32Array(HardwareRenderer.MINIMUM_TILE_COUNT_PER_BUFFER * 6);
      
      fillIndexBuffer();
    }
    else if (bufferOffset >= bufferSize)
    {
      var oldBuffer:Float32Array = buffer;
      
      bufferSize += HardwareRenderer.MINIMUM_TILE_COUNT_PER_BUFFER;
      buffer = new Float32Array(bufferSize * HardwareRenderer.TILE_SIZE);
      indexes = new UInt32Array(bufferSize * 6);
      
      var i:Int = 0;
      while (i < oldBuffer.length)
      {
        buffer[i] = oldBuffer[i];
        i++;
      }
      
      fillIndexBuffer();
    }
  }
  
  private inline function fillIndexBuffer():Void
  {
    var i:Int = 0;
    var vertexOffset:Int = 0;
    while (i < indexes.length)
    {
      indexes[i    ] = vertexOffset;//0;
      indexes[i + 1] = vertexOffset + 1;
      indexes[i + 2] = vertexOffset + 2;
      indexes[i + 3] = vertexOffset + 2;
      indexes[i + 4] = vertexOffset + 1;
      indexes[i + 5] = vertexOffset + 3;
      vertexOffset += 4;
      i += 6;
    }
    indexBufferDirty = true;
  }
  
	/**
	 * Get's the atlas data for a specific texture, useful for setting rendering flags
	 * @param	name	The name of the image file
	 * @return	An AtlasData object (will create one if it doesn't already exist)
	 */
	public static inline function getAtlasDataByName(name:String, create:Bool=false):AtlasData
	{
		var data:AtlasData = null;
		if (_dataPool.exists(name))
		{
			data = _dataPool.get(name);
		}
		else if(create)
		{
			var bitmap:BitmapData = HXP.getBitmap(name);
			if (bitmap != null)
			{
				data = new AtlasData(bitmap, name);
			}
		}
		return data;
	}

	/**
	 * String representation of AtlasData
	 * @return the name of the AtlasData
	 */
	public function toString():String
	{
		return (_name == null ? "AtlasData" : _name); 
	}

	/**
	 * Reloads the image for a particular atlas object
	 */
	public function reload(bd:BitmapData):Bool
	{
		if(_name != null)
			return HXP.overwriteBitmapCache(_name, bd);
		return false;
	}

	/**
	 * Sets the scene object
	 * @param	scene	The scene object to set
	 */
	@:allow(com.haxepunk.Scene)
	private static inline function startScene(scene:Scene):Void
	{
		_scene = scene;
    _scene.tilemap.clear();
    for (atlas in _atlases)
    {
      atlas.bufferOffset = 0;
    }
		//_scene.sprite.graphics.clear();
	}
	
	@:allow(com.haxepunk.Scene)
	private static inline function drawScene(scene:Scene):Void
	{
		DrawState.drawStates(scene);
	}

	/**
	 * Removes the object from memory
	 */
	public function destroy():Void
	{
		if (_name != null)
		{
			HXP.removeBitmap(_name);
			_dataPool.remove(_name);
		}
	}

	/**
	 * Removes all atlases from the display list
	 */
	public static function destroyAll():Void
	{
		for (atlas in _dataPool)
		{
			atlas.destroy();
		}
	}

	/**
	 * Creates a new AtlasRegion
	 * @param	rect	Defines the rectangle of the tile on the tilesheet
	 * @param	center	Positions the local center point to pivot on (not used)
	 *
	 * @return The new AtlasRegion object.
	 */
	public inline function createRegion(rect:Rectangle, ?center:Point):AtlasRegion
	{
		return new AtlasRegion(this, rect.clone());
	}
  
	/**
	 * Prepares a tile to be drawn using a matrix
	 * @param  rect   The source rectangle to draw
	 * @param  layer The layer to draw on
	 * @param  tx    X-Axis translation
	 * @param  ty    Y-Axis translation
	 * @param  a     Top-left
	 * @param  b     Top-right
	 * @param  c     Bottom-left
	 * @param  d     Bottom-right
	 * @param  red   Red color value
	 * @param  green Green color value
	 * @param  blue  Blue color value
	 * @param  alpha Alpha value
	 */
	public inline function prepareTileMatrix(rect:Rectangle, layer:Int,
		tx:Float, ty:Float, a:Float, b:Float, c:Float, d:Float,
		red:Float, green:Float, blue:Float, alpha:Float, ?smooth:Bool)
	{
		if (smooth == null) smooth = Atlas.smooth;
    
    //if (rect.width == 0 || rect.height == 0 || alpha == 0 || rect.right > width || rect.bottom > height || rect.top < 0 || rect.left < 0) throw "WUT";
    
    #if !display
		var state:DrawState = DrawState.getDrawState(this, _texture, smooth, blend);
    ensureElement();
    
		var data:Float32Array = buffer;
		var dataIndex:Int = bufferOffset * HardwareRenderer.TILE_SIZE;
    
    // UV
    var uvx:Float = (rect.x) / _texture.width;
    var uvy:Float = (rect.y) / _texture.height;
    var uvx2:Float = (rect.right) / _texture.width;
    var uvy2:Float = (rect.bottom) / _texture.height;
    
    // Transformed position
    var matrix:Matrix = HXP.matrix;
    matrix.setTo(a, b, c, d, tx, ty);
    
    // Position
    var x :Float = matrix.__transformX(0, 0); // Top-left
    var y :Float = matrix.__transformY(0, 0);
    var x2:Float = matrix.__transformX(rect.width, 0); // Top-right
    var y2:Float = matrix.__transformY(rect.width, 0);
    var x3:Float = matrix.__transformX(0, rect.height); // Bottom-left
    var y3:Float = matrix.__transformY(0, rect.height);
    var x4:Float = matrix.__transformX(rect.width, rect.height); // Bottom-right
    var y4:Float = matrix.__transformY(rect.width, rect.height);
    
    // Set values
    if (!isRGB)
    {
      red = 1;
      green = 1;
      blue = 1;
    }
    if (!isAlpha) alpha = 1;
    else
    {
      if (alpha < 0) alpha = 0;
      else if (alpha > 1) alpha = 1;
    }
    
    inline function fillTint():Void
    {
      data[dataIndex++] = red;
      data[dataIndex++] = green;
      data[dataIndex++] = blue;
      data[dataIndex++] = alpha;
    }
    
    // Triangle 1, top-left
    data[dataIndex++] = x;
    data[dataIndex++] = y;
    data[dataIndex++] = uvx;
    data[dataIndex++] = uvy;
    fillTint();
    // Triangle 1, top-right
    data[dataIndex++] = x2;
    data[dataIndex++] = y2;
    data[dataIndex++] = uvx2;
    data[dataIndex++] = uvy;
    fillTint();
    // Triangle 1, bottom-left
    data[dataIndex++] = x3;
    data[dataIndex++] = y3;
    data[dataIndex++] = uvx;
    data[dataIndex++] = uvy2;
    fillTint();
    //// Triangle 2, bottom-left
    //data[dataIndex++] = x3;
    //data[dataIndex++] = y3;
    //data[dataIndex++] = uvx;
    //data[dataIndex++] = uvy2;
    //fillTint();
    //// Triangle 2, top-right
    //data[dataIndex++] = x2;
    //data[dataIndex++] = y2;
    //data[dataIndex++] = uvx2;
    //data[dataIndex++] = uvy;
    //fillTint();
    // Triangle 2, bottom-right
    data[dataIndex++] = x4;
    data[dataIndex++] = y4;
    data[dataIndex++] = uvx2;
    data[dataIndex++] = uvy2;
    fillTint();
    
    bufferOffset++;
    state.count++;
    vertexBufferDirty = true;
    #end
	}

	/**
	 * Prepares a tile to be drawn
	 * @param  rect   The source rectangle to draw
	 * @param  x      The x-axis value
	 * @param  y      The y-axis value
	 * @param  layer  The layer to draw on
	 * @param  scaleX X-Axis scale
	 * @param  scaleY Y-Axis scale
	 * @param  angle  Angle (in degrees)
	 * @param  red    Red color value
	 * @param  green  Green color value
	 * @param  blue   Blue color value
	 * @param  alpha  Alpha value
	 */
	public inline function prepareTile(rect:Rectangle, x:Float, y:Float, layer:Int,
		scaleX:Float, scaleY:Float, angle:Float,
		red:Float, green:Float, blue:Float, alpha:Float, ?smooth:Bool)
	{
		if (smooth == null) smooth = Atlas.smooth;
    var matrix:Matrix = HXP.matrix;
    matrix.identity();
    matrix.scale(scaleX, scaleY);
    matrix.rotate( -angle * HXP.RAD);
    matrix.translate(x, y);
    prepareTileMatrix(rect, layer, matrix.tx, matrix.ty, matrix.a, matrix.b, matrix.c, matrix.d, red, green, blue, alpha, smooth);
	}

	/**
	 * Sets the blend mode for rendering (`BLEND_NONE`, `BLEND_NORMAL`, `BLEND_ADD`)
	 * Default: `BLEND_NORMAL`
	 */
	public var blend(default, set):Int = BLEND_NORMAL;
	private function set_blend(value:Int):Int
	{
		// check that value is actually a blend flag
		if (value == BLEND_ADD ||
			value == BLEND_MULTIPLY ||
			value == BLEND_SCREEN ||
			value == BLEND_NORMAL)
		{
			// set the blend flag
			blend = value;
		}
		
		return blend;
	}
	
	// used for pooling
	private var _name:String;

	private var _layerIndex:Int = 0;

	private var _texture:BitmapData;

	private static var _scene:Scene;
	private static var _dataPool:Map<String, AtlasData> = new Map<String, AtlasData>();
	private static var _uniqueId:Int = 0; // allows for unique names
  private static var _atlases:Array<AtlasData> = new Array();
}
