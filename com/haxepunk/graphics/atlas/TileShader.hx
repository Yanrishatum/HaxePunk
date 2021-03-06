package com.haxepunk.graphics.atlas;
import openfl.display.Shader;
import lime.graphics.opengl.GL;

/**
 * ...
 * @author Yanrishatum
 */
class TileShader extends Shader
{

  @:glVertexSource(
      "attribute vec4 aPosition;
      attribute vec4 aColor;
      attribute vec2 aTexCoord;
      varying vec2 vTexCoord;
      varying vec4 vColor;
      
      uniform mat4 uMatrix;
      
      void main(void) {
        
        vTexCoord = aTexCoord;
        vColor = aColor;
        gl_Position = uMatrix * aPosition;
        
      }"
  )
  @:glFragmentSource(
      "varying vec2 vTexCoord;
      varying vec4 vColor;
      uniform sampler2D uImage0;
      uniform float uAlpha;
      
      void main(void) {
        
        vec4 color = texelFetch (uImage0, ivec2(vTexCoord), 0);
        if (color.a == 0.0)
        {
          gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        }
        else
        {
          gl_FragColor = vec4 ((color.rgb / color.a) * vColor.rgb * color.a * vColor.a, color.a * uAlpha * vColor.a);
        }
        
      }"
  )
  public function new() 
  {
    super();
  }
  
}