package com.babylonhx.mesh;

import snow.render.opengl.GL.GLBuffer;


/**
 * ...
 * @author Krtolica Vujadin
 */

@:expose('BABYLON.BabylonBuffer') class BabylonBuffer {
	
	// TODO: this will depend on backend we use (Kha, OpenFL, Luxe...)
	public var buffer:GLBuffer;	
	public var references:Int;
	public var capacity:Int = 0;
	public var is32Bits:Bool = false;
	
	
	public function new(buffer:GLBuffer) {
		this.buffer = buffer;
		this.references = 1;
	}
	
}