//
//  CIImage+Ext.swift
//  Shadow_Image_Filter
//
//  Created by Maksim Ponomarev on 12/11/24.
//

import Foundation
import CoreImage

extension CIImage {
	func toCGImage() -> CGImage? {
		let context = CIContext(options: nil)
		if let cgImage = context.createCGImage(self, from: extent) {
			return cgImage
		}
		return nil
	}
}
