//
//  Metal_Filter.metal
//  Shadow_Image_Filter
//
//  Created by Maksim Ponomarev on 4/30/24.
//

#include <metal_stdlib>
using namespace metal;


struct VertexIn {
	float4 position [[ attribute(0) ]];
	float2 textureCoordinates [[ attribute(1) ]];
};

struct VertexOut {
	float4 position [[ position ]];
	float2 textureCoordinates;
	float highlight;
	float shadow;
};

struct ModelConstants {
	float highlight;
	float shadow;
};

vertex VertexOut vertex_func (const VertexIn vertexIn [[ stage_in ]],
							  constant ModelConstants &modelConstants [[ buffer(1) ]] ) {
	VertexOut vertexOut;
	vertexOut.position = vertexIn.position;
	vertexOut.textureCoordinates = vertexIn.textureCoordinates;
	vertexOut.highlight = modelConstants.highlight;
	vertexOut.shadow = modelConstants.shadow;
	
	return vertexOut;
}

static float4 convertFromRGBToYIQ(float4 src) {
	float3 pix2;
	float4 pix = src;
	/*
	 https://www.blackice.com/colorspaceYIQ.htm
	 https://www.eembc.org/techlit/datasheets/yiq_consumer.pdf
	 Y = 0.299*R + 0.587*G + 0.114*B
	 I = 0.596*R – 0.275*G – 0.321*B
	 Q = 0.212*R – 0.523*G + 0.311*B
	 */
	
	float Y = 0.299* pix.r + 0.587* pix.g + 0.114* pix.b;
	float I = 0.596* pix.r -0.275* pix.g -0.321* pix.b;
	float Q = 0.212* pix.r -0.523* pix.g + 0.311* pix.b;
	
	Y = min( max(0.0,Y), 255.0);
	
	pix2 = float3(Y, I, Q);
	
	return float4(pix2, src.w);
}

static float4 convertFromYIQToRGB(float4 src) {
	float4 color, pix;
	pix = src;
	color.xyz = ((pix.x* float3(1.000480e+00f, 9.998640e-01f, 9.994460e-01f))+ (pix.y* float3(9.555580e-01f, -2.715450e-01f, -1.108030e+00f)))+ (pix.z* float3(6.195490e-01f, -6.467860e-01f, 1.705420e+00f));
	color.xyz = max(color.xyz, float3(0.000000e+00f));
	color.xyz = color.xyz* color.xyz;
	color.w = pix.w;
	return color;
}


fragment half4 highlight_shader(VertexOut vertexIn [[ stage_in ]],
								texture2d<float> texture [[ texture(0) ]] ) {

	constexpr sampler defaultSampler(coord::normalized,
									 mag_filter::linear,
									 min_filter::linear);
	
	const float4 source = texture.sample(defaultSampler, vertexIn.textureCoordinates);
	float4 sourceYIQ = convertFromRGBToYIQ(source);
	
	float highlights_sign_negated = copysign(1.0, -vertexIn.highlight);
	float shadows_sign = copysign(1.0f, vertexIn.shadow);
	constexpr float compress = 0.5;
	constexpr float low_approximation = 0.01f;
	constexpr float shadowColor = 1.0;
	constexpr float highlightColor = 1.0;
	float tb0 = 1.0 - source.x - 0.4;
	if (tb0 < 1.0 - compress) {
		float highlights2 = pow(vertexIn.highlight,2);
		float highlights_xform = min(1.0f - tb0 / (1.0f - compress), 1.0f);
		while (highlights2 > 0.0f) {
			float lref, href;
			float chunk, optrans;
			
			float la = sourceYIQ.x;
			float la_abs;
			float la_inverted = 1.0f - la;
			float la_inverted_abs;
			float lb = (tb0 - 0.5f) * highlights_sign_negated * sign(la_inverted) + 0.5f;
			
			la_abs = abs(la);
			lref = copysign(la_abs > low_approximation ? 1.0f / la_abs : 1.0f / low_approximation, la);
			
			la_inverted_abs = abs(la_inverted);
			href = copysign(la_inverted_abs > low_approximation ? 1.0f / la_inverted_abs : 1.0f / low_approximation, la_inverted);
			
			chunk = highlights2 > 1.0f ? 1.0f : highlights2;
			optrans = chunk * highlights_xform;
			highlights2 -= 1.0f;
			
			sourceYIQ.x = la * (1.0 - optrans) + (la > 0.5f ? 1.0f - (1.0f - 2.0f * (la - 0.5f)) * (1.0f - lb) : 2.0f * la * lb) * optrans;
			
			sourceYIQ.y = sourceYIQ.y * (1.0f - optrans)
			+ sourceYIQ.y * (sourceYIQ.x * lref * (1.0f - highlightColor)
							 + (1.0f - sourceYIQ.x) * href * highlightColor) * optrans;
			
			sourceYIQ.z = sourceYIQ.z * (1.0f - optrans)
			+ sourceYIQ.z * (sourceYIQ.x * lref * (1.0f - highlightColor)
							 + (1.0f - sourceYIQ.x) * href * highlightColor) * optrans;
		}
	}
	if (tb0 > compress) {
		float shadows2 = pow(vertexIn.shadow,2);
		float shadows_xform = min(tb0 / (1.0f - compress) - compress / (1.0f - compress), 1.0f);
		
		while (shadows2 > 0.0f) {
			float lref, href;
			float chunk, optrans;
			
			float la = sourceYIQ.x;
			float la_abs;
			float la_inverted = 1.0f - la;
			float la_inverted_abs;
			float lb = (tb0 - 0.5f) * shadows_sign * sign(la_inverted) + 0.5f;
			
			la_abs = abs(la);
			lref = copysign(la_abs > low_approximation ? 1.0f / la_abs : 1.0f / low_approximation, la);
			
			la_inverted_abs = abs(la_inverted);
			href = copysign(la_inverted_abs > low_approximation ? 1.0f / la_inverted_abs : 1.0f / low_approximation,
							la_inverted);
			
			chunk = shadows2 > 1.0f ? 1.0f : shadows2;
			optrans = chunk * shadows_xform;
			shadows2 -= 1.0f;
			
			sourceYIQ.x = la * (1.0 - optrans)
			+ (la > 0.5f ? 1.0f - (1.0f - 2.0f * (la - 0.5f)) * (1.0f - lb) : 2.0f * la * lb) * optrans;
			
			sourceYIQ.y = sourceYIQ.y * (1.0f - optrans)
			+ sourceYIQ.y * (sourceYIQ.x * lref * shadowColor
							 + (1.0f - sourceYIQ.x) * href * (1.0f - shadowColor)) * optrans;
			
			sourceYIQ.z = sourceYIQ.z * (1.0f - optrans)
			+ sourceYIQ.z * (sourceYIQ.x * lref * shadowColor
							 + (1.0f - sourceYIQ.x) * href * (1.0f - shadowColor)) * optrans;
		}
	}
	return half4(convertFromYIQToRGB(sourceYIQ));
}
