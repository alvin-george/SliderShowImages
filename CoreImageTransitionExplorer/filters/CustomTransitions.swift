//
//  BlurTransition.swift
//  CoreImageTransitionExplorer
//
//  Created by Simon Gladman on 30/01/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import CoreImage

// MARK: Base class

class CustomTransitionFilter: CIFilter
{
    var inputImage: CIImage?
    var inputTargetImage: CIImage?
    
    var inputTime: CGFloat = 0.5
    
    var smoothedTime: CGFloat
    {
        return inputTime.smootherStep()
    }
    
    override var attributes: [String : Any]
    {
        return [
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage],
            
            "inputTargetImage": [kCIAttributeIdentity: 0,
                                 kCIAttributeClass: "CIImage",
                                 kCIAttributeDisplayName: "Target Image",
                                 kCIAttributeType: kCIAttributeTypeImage],
            
            "inputTime": [kCIAttributeIdentity: 0,
                          kCIAttributeClass: "NSNumber",
                          kCIAttributeDefault: 0.5,
                          kCIAttributeDisplayName: "Time",
                          kCIAttributeMin: 0,
                          kCIAttributeSliderMin: 0,
                          kCIAttributeSliderMax: 1,
                          kCIAttributeType: kCIAttributeTypeScalar]
        ]
    }
}

// MARK: StarTransition

class StarTransition: CustomTransitionFilter
{
    static func register()
    {
        if #available(iOS 9.0, *) {
            CIFilter.registerName("StarTransition",
                                  constructor: CustomFiltersVendor(),
                                  classAttributes: [
                                    kCIAttributeFilterCategories: ["CICategoryTransition"]
                ])
        } else {
            // Fallback on earlier versions
        }
    }
    
    let starGenerator = CIFilter(name: "CIStarShineGenerator",
                                 withInputParameters: [kCIInputColorKey: CIColor(red: 1, green: 1, blue: 1)])!
    
    override var outputImage: CIImage?
    {
        guard let inputImage = inputImage,
            let inputTargetImage = inputTargetImage else
        {
            return nil
        }
        
        let extent = inputImage.extent.union(inputTargetImage.extent)
        
        let centre = CGPoint(x: extent.midX, y: extent.midY)
        
        let maxRadius = centre.distanceTo(point: extent.origin)
        
        let rotationSpeedMultiplier = CGFloat(5)
        
        starGenerator.setValue(CIVector(cgPoint: centre), forKey: kCIInputCenterKey)
        starGenerator.setValue(maxRadius * smoothedTime, forKey: kCIInputRadiusKey)
        starGenerator.setValue(rotationSpeedMultiplier * inputTime, forKey: "inputCrossAngle")
        
        let mask = starGenerator.outputImage!.cropping(to: inputImage.extent)
        
        return inputTargetImage.applyingFilter("CIBlendWithMask",
                                               withInputParameters: [kCIInputBackgroundImageKey: inputImage, kCIInputMaskImageKey: mask])
    }
}

// MARK: CircleTransition

class CircleTransition: CustomTransitionFilter
{
    static func register()
    {
        if #available(iOS 9.0, *) {
            CIFilter.registerName("CircleTransition",
                                  constructor: CustomFiltersVendor(),
                                  classAttributes: [
                                    kCIAttributeFilterCategories: ["CICategoryTransition"]
                ])
        } else {
            // Fallback on earlier versions
        }
    }
    
    override var outputImage: CIImage?
    {
        guard let inputImage = inputImage,
            let inputTargetImage = inputTargetImage else
        {
            return nil
        }
        
        let extent = inputImage.extent.union(inputTargetImage.extent)
        
        let centre = CGPoint(x: extent.midX, y: extent.midY)
        
        let maxRadius = centre.distanceTo(point: extent.origin)
        
        let sourceImage = inputImage
            .applyingFilter("CIHoleDistortion", withInputParameters: [
                kCIInputCenterKey: CIVector(cgPoint: centre),
                kCIInputRadiusKey: maxRadius * smoothedTime]).cropping(to: inputImage.extent)
        
        return sourceImage.compositingOverImage(inputTargetImage)
    }
    
}

// MARK: BlurTransition

class BlurTransition: CustomTransitionFilter
{
    static func register()
    {
        if #available(iOS 9.0, *) {
            CIFilter.registerName("BlurTransition",
                                  constructor: CustomFiltersVendor(),
                                  classAttributes: [
                                    kCIAttributeFilterCategories: ["CICategoryTransition"]
                ])
        } else {
            // Fallback on earlier versions
        }
    }
    
    let maxBlur = CGFloat(100)
    
    override var outputImage: CIImage?
    {
        guard let inputImage = inputImage,
            let inputTargetImage = inputTargetImage else
        {
            return nil
        }
        
        let blurredSource = inputImage
            .applyingFilter("CIGaussianBlur", withInputParameters: [kCIInputRadiusKey: smoothedTime * maxBlur])
            .cropping(to: inputImage.extent)
        
        let blurredTarget = inputTargetImage
            .applyingFilter("CIGaussianBlur", withInputParameters: [kCIInputRadiusKey: (1 - smoothedTime) * maxBlur])
            .cropping(to: inputTargetImage.extent)
        
        let finalImage = blurredSource
            .applyingFilter("CIDissolveTransition", withInputParameters: [
                kCIInputTargetImageKey: blurredTarget,
                kCIInputTimeKey: inputTime])
        
        return finalImage
    }
}

class CustomFiltersVendor: NSObject, CIFilterConstructor
{
    func filter(withName name: String) -> CIFilter? {
        
        switch name
        {
        case "BlurTransition":
            return BlurTransition()
            
        case "CircleTransition":
            return CircleTransition()
            
        case "StarTransition":
            return StarTransition()
            
        default:
            return nil
        }
    }
}

extension CGPoint
{
    func distanceTo(point: CGPoint) -> CGFloat
    {
        return hypot(self.x - point.x, self.y - point.y)
    }
}

extension CGFloat
{
    func saturate() -> CGFloat
    {
        return self < 0 ? 0 : self > 1 ? 1 : self
    }
    
    func smootherStep() -> CGFloat
    {
        let x = self.saturate()
        
        return ((x) * (x) * (x) * ((x) * ((x) * 6 - 15) + 10))
    }
}
