package com.babylonhx.postprocess;

import com.babylonhx.materials.Effect;
import com.babylonhx.materials.textures.RenderTargetTexture;
import com.babylonhx.materials.textures.Texture;
import com.babylonhx.cameras.Camera;
import com.babylonhx.postprocess.renderpipeline.PostProcessRenderEffect;
import com.babylonhx.postprocess.renderpipeline.PostProcessRenderPipeline;
import com.babylonhx.tools.Tools;

/**
 * ...
 * @author Krtolica Vujadin
 */

@:expose('BABYLON.LensRenderingPipeline') class LensRenderingPipeline extends PostProcessRenderPipeline {

	// Lens effects can be of the following:
	// - chromatic aberration (slight shift of RGB colors)
	// - blur on the edge of the lens
	// - lens distortion
	// - depth-of-field 'bokeh' effect (shapes appearing in blured areas, stronger highlights)
	// - grain/dust-on-lens effect

	// Two additional texture samplers are needed:
	// - depth map (for depth-of-field)
	// - grain texture

	/**
	* The chromatic aberration PostProcess id in the pipeline
	* @type {string}
	*/
	public var LensChromaticAberrationEffect:String = "LensChromaticAberrationEffect";
	/**
	* The depth-of-field PostProcess id in the pipeline
	* @type {string}
	*/
	public var LensDepthOfFieldEffect:String = "LensDepthOfFieldEffect";

	private var _scene:Scene;
	private var _depthTexture:RenderTargetTexture;
	private var _grainTexture:Texture;

	private var _chromaticAberrationPostProcess:PostProcess;
	private var _depthOfFieldPostProcess:PostProcess;

	private var _edgeBlur:Float;
	private var _grainAmount:Float;
	private var _chromaticAberration:Float;
	private var _distortion:Float;
	private var _highlightsGain:Float;
	private var _highlightsThreshold:Float;
	private var _dofDepth:Float;
	private var _dofAperture:Float;
	private var _dofPentagon:Bool;
	private var _blurNoise:Bool;
	

	/**
	 * @constructor
	 * @param {string} name - The rendering pipeline name
	 * @param {object} parameters - An object containing all parameters (see below)
	 * @param {BABYLON.Scene} scene - The scene linked to this pipeline
	 * @param {number} ratio - The size of the postprocesses (0.5 means that your postprocess will have a width = canvas.width 0.5 and a height = canvas.height 0.5)
	 * @param {BABYLON.Camera[]} cameras - The array of cameras that the rendering pipeline will be attached to
		Effect parameters are as follow:
		{
			chromatic_aberration: number;		// from 0 to x (1 for realism)
			edge_blur: number;					// from 0 to x (1 for realism)
			distortion: number;					// from 0 to x (1 for realism)
			grain_amount: number;				// from 0 to 1
			grain_texture: BABYLON.Texture;		// texture to use for grain effect; if unset, use random B&W noise
			dof_focus_depth: number;			// depth-of-field: focus depth; unset to disable
			dof_aperture: number;				// depth-of-field: focus blur bias (default: 1)
			dof_pentagon: boolean;				// depth-of-field: makes a pentagon-like "bokeh" effect
			dof_gain: boolean;					// depth-of-field: depthOfField gain (default: 1)
			dof_threshold: boolean;				// depth-of-field: depthOfField threshold (default: 1)
			blur_noise: boolean;				// add a little bit of noise to the blur (default: true)
		}
		Note: if an effect parameter is unset, effect is disabled
	 */
	public function new(name:String, parameters:Dynamic, scene:Scene, ratio:Float = 1.0, ?cameras:Array<Camera>) {
		super(scene.getEngine(), name);
		
		this._scene = scene;
		
		// Fetch texture samplers
		this._depthTexture = scene.enableDepthRenderer().getDepthMap(); // Force depth renderer "on"
		if (parameters.grain_texture != null) {
			this._grainTexture = parameters.grain_texture;
		} else {
			 this._createGrainTexture();
		}
		
		// save parameters
		this._edgeBlur = parameters.edge_blur != null ? parameters.edge_blur : 0;
		this._grainAmount = parameters.grain_amount != null ? parameters.grain_amount : 0;
		this._chromaticAberration = parameters.chromatic_aberration != null ? parameters.chromatic_aberration : 0;
		this._distortion = parameters.distortion != null ? parameters.distortion : 0;
		this._highlightsGain = parameters.dof_gain != null ? parameters.dof_gain : 1;
		this._highlightsThreshold = parameters.dof_threshold != null ? parameters.dof_threshold : 1;
		this._dofDepth = parameters.dof_focus_depth != null ? parameters.dof_focus_depth : -1;
		this._dofAperture = parameters.dof_aperture != null ? parameters.dof_aperture : 1;
		this._dofPentagon = parameters.dof_pentagon != null ? parameters.dof_pentagon : true;
		this._blurNoise = parameters.blur_noise != null ? parameters.blur_noise : true;
		
		// Create effects
		this._createChromaticAberrationPostProcess(ratio);
		this._createDepthOfFieldPostProcess(ratio);
		
		// Set up pipeline
		this.addEffect(new PostProcessRenderEffect(scene.getEngine(), this.LensChromaticAberrationEffect, function():PostProcess { return this._chromaticAberrationPostProcess; }, true));
		this.addEffect(new PostProcessRenderEffect(scene.getEngine(), this.LensDepthOfFieldEffect, function():PostProcess { return this._depthOfFieldPostProcess; }, true));

		// Finish
		scene.postProcessRenderPipelineManager.addPipeline(this);
		if(cameras != null && cameras.length > 0) {
			scene.postProcessRenderPipelineManager.attachCamerasToRenderPipeline(name, cameras);
		}
	}

	// public methods
	public function setEdgeBlur(amount:Float) { this._edgeBlur = amount; }
	public function disableEdgeBlur() { this._edgeBlur = 0; }
	public function setGrainAmount(amount:Float) { this._grainAmount = amount; }
	public function disableGrain() { this._grainAmount = 0; }
	public function setChromaticAberration(amount:Float) { this._chromaticAberration = amount; }
	public function disableChromaticAberration() { this._chromaticAberration = 0; }
	public function setEdgeDistortion(amount:Float) { this._distortion = amount; }
	public function disableEdgeDistortion() { this._distortion = 0; }
	public function setHighlightsGain(amount:Float) { this._highlightsGain = amount; }
	public function setHighlightsThreshold(amount:Float) { this._highlightsThreshold = amount; }
	public function setFocusDepth(amount:Float) { this._dofDepth = amount; }
	public function disableDepthOfField() { this._dofDepth = -1; }
	public function setAperture(amount:Float) { this._dofAperture = amount; }
	public function enablePentagonBokeh() { this._dofPentagon = true; }
	public function disablePentagonBokeh() { this._dofPentagon = false; }
	public function enableNoiseBlur() { this._blurNoise = true; }
	public function disableNoiseBlur() { this._blurNoise = false; }

	/**
	 * Removes the internal pipeline assets and detaches the pipeline from the scene cameras
	 */
	public function dispose(disableDepthRender:Bool = false) {
		this._scene.postProcessRenderPipelineManager.detachCamerasFromRenderPipeline(this._name, this._scene.cameras);
		
		this._chromaticAberrationPostProcess = undefined;
		this._depthOfFieldPostProcess = undefined;
		
		this._grainTexture.dispose();
		
		if (disableDepthRender)
			this._scene.disableDepthRenderer();
	}

	// colors shifting and distortion
	private function _createChromaticAberrationPostProcess(ratio:Float) {
		this._chromaticAberrationPostProcess = new PostProcess("LensChromaticAberration", "chromaticAberration",
			["chromatic_aberration", "screen_width", "screen_height"],		// uniforms
			[],											// samplers
			ratio, null, Texture.TRILINEAR_SAMPLINGMODE,
			this._scene.getEngine(), false);
			
		this._chromaticAberrationPostProcess.onApply = (effect: Effect) => {
			effect.setFloat('chromatic_aberration', this._chromaticAberration);
			effect.setFloat('screen_width', this._scene.getEngine().getRenderWidth());
			effect.setFloat('screen_height', this._scene.getEngine().getRenderHeight());
		};
	}

	// colors shifting and distortion
	private function _createDepthOfFieldPostProcess(ratio:Float) {
		this._depthOfFieldPostProcess = new PostProcess("LensDepthOfField", "depthOfField",
			[
				"gain", "threshold", "focus_depth", "aperture", "pentagon", "maxZ", "edge_blur",
				"chromatic_aberration", "distortion", "blur_noise", "grain_amount", "screen_width", "screen_height"
			],
			["depthSampler", "grainSampler"],
			ratio, null, Texture.TRILINEAR_SAMPLINGMODE,
			this._scene.getEngine(), false);
			
		this._depthOfFieldPostProcess.onApply = function(effect:Effect) {
			effect.setBool('pentagon', this._dofPentagon);
			effect.setBool('blur_noise', this._blurNoise);
			effect.setFloat('maxZ', this._scene.activeCamera.maxZ);
			effect.setFloat('grain_amount', this._grainAmount);
			
			effect.setTexture("depthSampler", this._depthTexture);
			effect.setTexture("grainSampler", this._grainTexture);
			
			effect.setFloat('screen_width', this._scene.getEngine().getRenderWidth());
			effect.setFloat('screen_height', this._scene.getEngine().getRenderHeight());
			
			effect.setFloat('distortion', this._distortion);
			
			effect.setFloat('focus_depth', this._dofDepth);
			effect.setFloat('aperture', this._dofAperture);
			effect.setFloat('gain', this._highlightsGain);
			effect.setFloat('threshold', this._highlightsThreshold);
			
			effect.setFloat('edge_blur', this._edgeBlur);
		};
	}

	// creates a black and white random noise texture, 512x512
	private function _createGrainTexture() {
		// TODO
		/*var size = 512;
		
		this._grainTexture = new DynamicTexture("LensNoiseTexture", size, this._scene, false, Texture.BILINEAR_SAMPLINGMODE);
		this._grainTexture.wrapU = Texture.WRAP_ADDRESSMODE;
		this._grainTexture.wrapV = Texture.WRAP_ADDRESSMODE;
		
		var context = (<DynamicTexture>this._grainTexture).getContext();
		
		var rand = function(min:Float, max:Float):Float {
			return Math.random() * (max - min) + min;
		}
		
		var value:Int = 0;
		for (x in 0...size) {
			for (y in 0...size) {
				value = Math.floor(rand(0.42,0.58)*255);
				context.fillStyle = 'rgb(' + value + ', ' + value + ', ' + value + ')';
				context.fillRect(x, y, 1, 1);
			}
		}
		(<DynamicTexture>this._grainTexture).update(false);*/
	}

}
