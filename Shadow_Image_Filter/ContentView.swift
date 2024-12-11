//
//  ContentView.swift
//  Shadow_Image_Filter
//
//  Created by Maksim Ponomarev on 12/11/24.
//

import SwiftUI

struct ContentView: View {
	
	@State private var image: Image = Image(.beach)
	@State private var highlightPoints: Double = 0
	@State private var shadowPoints: Double = 0
	
	var body: some View {
		ZStack {
			VStack {
				HStack {
					Rectangle()
						.foregroundStyle(
							.black.opacity(0.8)
						)
				}
			}
			
			VStack {
				image
					.resizable()
					.frame(
						width: 300,
						height: 300
					)
				
				Slider(
					value: $highlightPoints,
					in: -100...100,
					step: 1
				) { _ in
					// will update image only after slider was released
					// updateImage()
				}
				.tint(tintColor(for: highlightPoints))
				.padding()
				
				Text("Highlight intensity: \(Int(highlightPoints))")
					.font(.headline)
					.foregroundStyle(.white)
				
			} //: VStack
			.padding()
			
		} //: ZStack
		.ignoresSafeArea()
		.onChange(of: highlightPoints) { _, _ in
			updateImage()
		}
	}
	
	func tintColor(for intensityPoints: Double) -> Color {
		switch intensityPoints {
		case 0:
			return Color(uiColor: UIColor.darkGray)
		case ...(-1):
			return Color.blue
		case 1...:
			return Color.red
		default:
			return .clear
		}
	}
	
	func updateImage() {
		Task.detached(priority: .userInitiated) { @MainActor in
			let parameters = HighlightShaderParameters(
				highlight: Float(highlightPoints),
				shadow: Float(shadowPoints)
			)
			guard
				let filteredImage = FilterBasement.shared.getImageWithFilter(
					filter: .highlightShader(parameters),
					image: UIImage(resource: .beach)
				)
			else {
				image = Image(systemName: "exclamationmark")
				return
			}
			
			guard
				let cgImage = filteredImage.ciImage?.toCGImage()
			else {
				image = Image(systemName: "exclamationmark")
				return
			}
			
			let uiImage = UIImage(cgImage: cgImage)
			let image = Image(uiImage: uiImage)
			self.image = image
		}
	}
}

#Preview {
	ContentView()
}
