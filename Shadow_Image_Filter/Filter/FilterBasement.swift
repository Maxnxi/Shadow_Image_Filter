//
//  FilterBasement.swift
//  Shadow_Image_Filter
//
//  Created by Maksim Ponomarev on 04/30/24.
//
// https://gist.github.com/Khrob/6232fdd4f75fdb1103d9dde80495d40e

import UIKit
import MetalKit

class FilterBasement {
	static let shared = FilterBasement()
	
	enum Constants {
		static let vertexFunc = "vertex_func"
	}
	
	func getImageWithFilter(
		filter: FilterType,
		image: UIImage
	) -> UIImage? {
		print("🔍 Starting image filter process")
		print("📱 Input image size: \(image.size)")
		
		struct ModelConstants {
			var highlight: Float = 0.0
			var shadow: Float = 0.0
		}
		
		struct Vertex {
			var position: simd_float3 = [0,0,0]
			var textureCoordinates: simd_float2 = [0,0]
		}
		
		let drawingFunction = filter.metalFunctionName
		print("🎨 Using metal function: \(drawingFunction)")
		
		var modelConstants: ModelConstants
		switch filter {
		case .highlightShader(let parameters):
			modelConstants = ModelConstants(
				highlight: parameters.highlight / 100,
				shadow: parameters.shadow / 100
			)
			print("⚙️ Filter parameters - Highlight: \(parameters.highlight), Shadow: \(parameters.shadow)")
		default:
			modelConstants = ModelConstants()
			print("⚙️ Using default model constants")
		}
		
		let indices: [UInt16] = [
			0,1,2,
			2,3,0
		]
		
		let view_corner_verts : [Vertex] = [
			Vertex(position: simd_float3(-1, 1,0), textureCoordinates: simd_float2(0,1)),
			Vertex(position: simd_float3(-1,-1,0), textureCoordinates: simd_float2(0,0)),
			Vertex(position: simd_float3( 1,-1,0), textureCoordinates: simd_float2(1,0)),
			Vertex(position: simd_float3( 1, 1,0), textureCoordinates: simd_float2(1,1)),
		]
		
		/// Set up the stuff Metal needs
		guard let device = MTLCreateSystemDefaultDevice() else {
			print("❌ Failed to create Metal device")
			return nil
		}
		print("✅ Metal device created: \(device.name)")
		
		guard let library = device.makeDefaultLibrary() else {
			print("❌ Failed to create Metal library")
			return nil
		}
		print("✅ Metal library created")
		
		let commandQueue = device.makeCommandQueue()!
		let commandBuffer = commandQueue.makeCommandBuffer()!
		print("✅ Command queue and buffer created")
		
		/// convertUIImage to MTLTexture
		let textureLoader = MTKTextureLoader(device: device)
		guard
			let cgImage = image.cgImage,
			let texture = try? textureLoader.newTexture(cgImage: cgImage)
		else {
			print("❌ Failed to create texture from image")
			return nil
		}
		print("✅ Input texture created - Size: \(texture.width)x\(texture.height)")
		
		/// Create an MTLTexture to render into
		let textureDescriptor = MTLTextureDescriptor()
		textureDescriptor.width = Int(image.size.width)
		textureDescriptor.height = Int(image.size.height)
		textureDescriptor.pixelFormat = .bgra8Unorm
		textureDescriptor.usage = [.renderTarget, .shaderRead]
		guard
			let textureOutput = device.makeTexture(descriptor: textureDescriptor)
		else {
			print("❌ Failed to create output texture")
			return nil
		}
		print("✅ Output texture created")
		
		/// Create a render pipeline to do the rendering
		let pass_descriptor = MTLRenderPassDescriptor()
		pass_descriptor.colorAttachments[0].texture = textureOutput
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.colorAttachments[0].pixelFormat = textureOutput.pixelFormat
		
		guard let vertexFunction = library.makeFunction(name: Constants.vertexFunc) else {
			print("❌ Failed to create vertex function")
			return nil
		}
		pipelineDescriptor.vertexFunction = vertexFunction
		
		guard let fragmentFunction = library.makeFunction(name: drawingFunction) else {
			print("❌ Failed to create fragment function")
			return nil
		}
		pipelineDescriptor.fragmentFunction = fragmentFunction
		print("✅ Shader functions created")
		
		let vertexDescriptor = MTLVertexDescriptor()
		vertexDescriptor.attributes[0].format = .float3
		vertexDescriptor.attributes[0].offset = 0
		vertexDescriptor.attributes[0].bufferIndex = 0
		vertexDescriptor.attributes[1].format = .float2
		vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
		vertexDescriptor.attributes[1].bufferIndex = 0
		vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
		pipelineDescriptor.vertexDescriptor = vertexDescriptor
		
		guard
			let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor),
			var vertexBuffer: MTLBuffer = device.makeBuffer(
				bytes: view_corner_verts,
				length: view_corner_verts.count * MemoryLayout<Vertex>.stride,
				options: []
			),
			var indexBuffer: MTLBuffer = device.makeBuffer(
				bytes: indices,
				length: indices.count * MemoryLayout<UInt16>.size,
				options: []
			)
		else {
			print("❌ Failed to create pipeline state or buffers")
			return nil
		}
		print("✅ Pipeline state and buffers created")
		
		/// Do the rendering
		guard
			let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass_descriptor)
		else {
			print("❌ Failed to create command encoder")
			return nil
		}
		
		print("🎬 Starting render pass")
		commandEncoder.setRenderPipelineState(pipelineState)
		commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
		commandEncoder.setVertexBytes(&modelConstants, length: MemoryLayout<ModelConstants>.stride, index: 1)
		commandEncoder.setFragmentTexture(texture, index: 0)
		commandEncoder.drawIndexedPrimitives(
			type: .triangle,
			indexCount: indices.count,
			indexType: .uint16,
			indexBuffer: indexBuffer,
			indexBufferOffset: 0
		)
		commandEncoder.endEncoding()
		
		/// Wait until the GPU is done
		commandBuffer.commit()
		print("⏳ Waiting for GPU to complete...")
		commandBuffer.waitUntilCompleted()
		print("✅ GPU processing completed")
		
		/// Convert the MTLTexture into a UIImage and return it
		guard
			let cii = CIImage(mtlTexture: textureOutput, options: nil)
		else {
			print("❌ Failed to create CIImage from texture")
			return nil
		}
		let resultImage = UIImage(ciImage: cii)
		print("✅ Successfully created filtered image")
		print("📱 Output image size: \(resultImage.size)")
		
		return resultImage
	}
}
