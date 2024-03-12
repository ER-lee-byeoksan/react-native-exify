import PhotosUI

@objc(Exify)
class Exify: NSObject {

  func readFromFile(uri: String, resolve: @escaping RCTPromiseResolveBlock) -> Void {
    let metadata = getMetadata(from: URL(string: uri))
    resolve(metadata)
  }

  func readFromAsset(uri: String, resolve: @escaping RCTPromiseResolveBlock) -> Void {
    let assetId = String(uri[uri.index(uri.startIndex, offsetBy: 5)...])
    guard let asset = getAssetBy(id: assetId) else {
      resolve(nil)
      return
    }

    let imageOptions = PHContentEditingInputRequestOptions()
    imageOptions.isNetworkAccessAllowed = true

    asset.requestContentEditingInput(with: imageOptions) { contentInput, info in
      guard let url = contentInput?.fullSizeImageURL else {
        resolve(nil)
        return
      }
      
      let metadata = getMetadata(from: url)
      resolve(metadata)
    }
  }
  
  func writeToAsset(uri: String, data: [String: Any], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
    let assetId = String(uri[uri.index(uri.startIndex, offsetBy: 5)...])
    guard let asset = getAssetBy(id: assetId) else {
      reject("Error", "Cannot retrieve asset.", nil)
      return
    }
    
    let imageOptions = PHContentEditingInputRequestOptions()
    imageOptions.isNetworkAccessAllowed = true
    
    asset.requestContentEditingInput(with: imageOptions) { contentInput, _ in
      guard let contentInput, let url = contentInput.fullSizeImageURL else {
        reject("Error", "Unable to read metadata from asset", nil)
        return
      }
      
      updateMetadata(url: url, with: data) { metadata, data in
        guard let metadata, let data else {
          reject("Error", "Could not update metadata", nil)
          return
        }
        
        do {
          try PHPhotoLibrary.shared().performChangesAndWait{
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: nil)
            request.creationDate = Date()
            
            let assetId = request.placeholderForCreatedAsset!.localIdentifier
            resolve([
              "uri": "ph://\(assetId)",
              "assetId": assetId,
              "exif": metadata
            ])
            
          }
        } catch let error {
          reject("Error", "Could not save to image file", nil)
          print(error)
        }
      }
    }
  }
  
  func writeToLocal(uri: String, data: [String: Any], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
    guard let url = URL(string: uri) else {
      reject("Error", "Invalid URL", nil)
      return
    }

    updateMetadata(url: url, with: data) { metadata, data in
      guard let metadata, let data else {
        reject("Error", "Could not update metadata", nil)
        return
      }
      
      do {
        // Write to the current file
        try data.write(to: url, options: .atomic)

        resolve([
          "uri": uri,
          "assetId": nil,
          "exif": metadata
        ])
        
      } catch let error {
        reject("Error", "Could not save to image file", nil)
        print(error)
      }
    }
  }

  @objc(readAsync:withResolver:withRejecter:)
  func readAsync(uri: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
    if uri.starts(with: "ph://") {
      readFromAsset(uri: uri, resolve: resolve)
    } else {
      readFromFile(uri: uri, resolve: resolve)
    }
  }

  @objc(writeAsync:withExif:withResolver:withRejecter:)
  func writeAsync(uri: String, data: [String: Any], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) -> Void {
    if uri.starts(with: "ph://") {
      writeToAsset(uri: uri, data: data, resolve: resolve, reject: reject)
    } else {
      writeToLocal(uri: uri, data: data, resolve: resolve, reject: reject)
    }
  }
}
