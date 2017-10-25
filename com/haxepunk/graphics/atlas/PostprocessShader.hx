package com.haxepunk.graphics.atlas;
import openfl.display.Shader;

/**
 * ...
 * @author 
 */
class PostprocessShader extends Shader
{

  @:glVertexSource(
			"
      attribute vec4 aPosition;
			attribute vec2 aTexCoord;
			varying vec2 vTexCoord;
      
			uniform mat4 uMatrix;
			
			void main(void) {
				
				vTexCoord = aTexCoord;
        gl_Position = aPosition;
				
			}"
  )
  @:glFragmentSource(
			"varying vec2 vTexCoord;
			uniform sampler2D uImage0;
			
			void main(void) {
				
        gl_FragColor = texture2D(uImage0, vTexCoord);
        
			}"
  )
  public function new() 
  {
    super();
  }
}