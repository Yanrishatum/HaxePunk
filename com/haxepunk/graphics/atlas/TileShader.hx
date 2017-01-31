package com.haxepunk.graphics.atlas;
import openfl.display.Shader;
import openfl.gl.GL;

/**
 * ...
 * @author Yanrishatum
 */
class TileShader extends Shader
{

  @:glVertexSource(
			"attribute vec4 aPosition;
			attribute vec2 aTexCoord;
      attribute vec4 aColor;
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
				
				vec4 color = texture2D (uImage0, vTexCoord);
        if (color.a == 0.0)
        {
          gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
        }
        else
        {
          gl_FragColor = vec4 ((color.rgb / color.a) * vColor.rgb * color.a * vColor.a, color.a*uAlpha*vColor.a);
        }
        
			}"
  )
  public function new() 
  {
    super();
  }
  
}