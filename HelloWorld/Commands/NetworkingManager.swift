import Foundation
import UIKit

// MARK: - Response Models

enum ContentType: String, Codable {
    case slides
    case chemistry
    case math
}

// Base response structure
struct BaseResponse: Codable {
    let type: ContentType
}

// Specific response types
struct SlidesResponse: Codable {
    let type: ContentType
    let slides: [String]
    let audio_link: String
}

struct ChemistryResponse: Codable {
    let type: ContentType
    let gif_url: String
    let audio_link: String
}

struct MathResponse: Codable {
    let type: ContentType
    let video_url: String
    let audio_link: String
}

// MARK: - Final Response Models

enum ContentMedia {
    case slides([UIImage])
    case gif(String) // For animated GIFs, you might want to use a specialized GIF handling library
    case video(String)
}

struct FinalAIResponse {
    let contentType: ContentType
    let media: ContentMedia
    let audioURL: String
}

@MainActor
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    private let baseURL = "http://10.49.144.66:8000"
    
    private init() {}
    
    private func log(_ message: String, isError: Bool = false) {
        let prefix = isError ? "❌ [NetworkManager Error]" : "📡 [NetworkManager]"
        print("\(prefix) \(message)")
    }
    
    private func processURL(_ urlString: String) -> String {
        return urlString.replacingOccurrences(of: "https://tmpfiles.org/", with: "https://tmpfiles.org/dl/")
    }
    
    private func downloadImage(from urlString: String) async throws -> UIImage {
        let processedURL = processURL(urlString)
        
        guard let url = URL(string: processedURL) else {
            log("Invalid URL: \(processedURL)", isError: true)
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            log("Failed to download image from URL: \(processedURL)", isError: true)
            throw NetworkError.downloadFailed
        }
        
        guard let image = UIImage(data: data) else {
            log("Failed to convert data to image from URL: \(processedURL)", isError: true)
            throw NetworkError.invalidImageData
        }
        
        return image
    }
    
    func sendPrompt(_ text: String, sceneImage: UIImage?) async throws -> FinalAIResponse {
        let endpoint = "\(baseURL)/handle-ar-content"
        log("Starting network request to endpoint: \(endpoint)")
        
        guard let image = sceneImage else {
            log("No image provided", isError: true)
            throw NetworkError.noImageProvided
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            log("Failed to convert image to JPEG data", isError: true)
            throw NetworkError.imageConversionFailed
        }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Create multipart form data
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
        body.append("\(text)\r\n")
        body.append("--\(boundary)--\r\n")
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            log("Server returned error", isError: true)
            throw NetworkError.serverError
        }
        
        // First decode the base response to get the type
        let decoder = JSONDecoder()
        let baseResponse = try decoder.decode(BaseResponse.self, from: data)
        
        // Process based on content type
        switch baseResponse.type {
        case .slides:
            let slidesResponse = try decoder.decode(SlidesResponse.self, from: data)
            var images: [UIImage] = []
            for urlString in slidesResponse.slides {
                let image = try await downloadImage(from: urlString)
                images.append(image)
            }
            return FinalAIResponse(
                contentType: .slides,
                media: .slides(images),
                audioURL: processURL(slidesResponse.audio_link)
            )
            
        case .chemistry:
            let chemistryResponse = try decoder.decode(ChemistryResponse.self, from: data)
            
            return FinalAIResponse(
                contentType: .chemistry,
                media: .gif(processURL(chemistryResponse.gif_url)),
                audioURL: processURL(chemistryResponse.audio_link)
            )
            
        case .math:
            let mathResponse = try decoder.decode(MathResponse.self, from: data)
            
            return FinalAIResponse(
                contentType: .math,
                media: .video(processURL(mathResponse.video_url)),
                audioURL: processURL(mathResponse.audio_link)
            )
        }
    }
}

// MARK: - Error Handling

enum NetworkError: Error {
    case invalidURL
    case downloadFailed
    case invalidImageData
    case noImageProvided
    case imageConversionFailed
    case serverError
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
