import Foundation
import UIKit

struct AIResponse: Codable {
    let status: String
    let slides: [String] // URLs as strings
    let audio_link: String
}

struct FinalAIResponse {
    let slides: [UIImage]
    let audioURL: String
}

@MainActor
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    private let baseURL = "http://10.49.31.123:8000"
    private init() {}
    
    private func log(_ message: String, isError: Bool = false) {
        let prefix = isError ? "❌ [NetworkManager Error]" : "📡 [NetworkManager]"
        print("\(prefix) \(message)")
    }
    
    private func downloadImage(from urlString: String) async throws -> UIImage {
        let urlString = urlString.replacingOccurrences(of: "https://tmpfiles.org/", with: "https://tmpfiles.org/dl/")

        guard let url = URL(string: urlString) else {
            log("Invalid URL: \(urlString)", isError: true)
            throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            log("Failed to download image from URL: \(urlString)", isError: true)
            throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to download image"])
        }
        
        guard let image = UIImage(data: data) else {
            log("Failed to convert data to image from URL: \(urlString)", isError: true)
            throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        
        return image
    }
    
    func sendPrompt(_ text: String) async throws -> FinalAIResponse {
        let endpoint = "\(baseURL)/handle-ar-content"
        log("Starting network request to endpoint: \(endpoint)")
        log("Prompt text: \(text)")
        
        // Load and process image
        guard let image = UIImage(named: "good-professional-pic") else {
            log("Failed to load image from assets: good-professional-pic", isError: true)
            throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation failed"])
        }
        log("Successfully loaded image from assets")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            log("Failed to convert image to JPEG data", isError: true)
            throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation failed"])
        }
        log("Successfully converted image to JPEG data (size: \(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file)))")
        
        // Generate boundary string
        let boundary = UUID().uuidString
        log("Generated boundary: \(boundary)")
        
        // Create URL request
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create multipart form data
        var body = Data()
        
        // Add image file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        
        // Add prompt text
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
        body.append("\(text)\r\n")
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n")
        
        request.httpBody = body
        log("Created request body (total size: \(ByteCountFormatter.string(fromByteCount: Int64(body.count), countStyle: .file)))")
        
        // Make network request
        log("Sending request...")
        let requestStartTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let requestDuration = Date().timeIntervalSince(requestStartTime)
        log("Request completed in \(String(format: "%.2f", requestDuration))s")
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            log("Server returned error", isError: true)
            throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation failed"])
        }
        
        let decoder = JSONDecoder()
        let aiResponse = try decoder.decode(AIResponse.self, from: data)
        log("Successfully decoded response with \(aiResponse.slides.count) slide URLs")
        
        // Download images from URLs
        var images: [UIImage] = []
        for (index, urlString) in aiResponse.slides.enumerated() {
            do {
                let image = try await downloadImage(from: urlString)
                images.append(image)
                log("Successfully downloaded image \(index + 1)/\(aiResponse.slides.count)")
            } catch {
                log("Failed to download image at index \(index): \(error.localizedDescription)", isError: true)
                throw error
            }
        }
        
        log("Successfully downloaded all \(images.count) images")
        
        let newAudioUrl = aiResponse.audio_link.replacingOccurrences(of: "https://tmpfiles.org/", with: "https://tmpfiles.org/dl/")

        let ret = FinalAIResponse(slides: images, audioURL: newAudioUrl)
        return ret
    }
}

// Extension to help with multipart form data
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
