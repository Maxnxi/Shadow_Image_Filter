//
//  FilterType.swift
//  Shadow_Image_Filter
//
//  Created by Maksim Ponomarev on 12/11/24.
//

enum FilterType {
	case highlightShader(HighlightShaderParameters)
	
	var metalFunctionName: String {
		switch self {
		case .highlightShader:
			return "highlight_shader"
		}
	}
}

struct HighlightShaderParameters {
	var highlight: Float = 0
	var shadow: Float = 0
}
