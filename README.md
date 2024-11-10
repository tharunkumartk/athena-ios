# Athena 🌟

![Athena AR](https://via.placeholder.com/800x400?text=Athena+AR)

Athena is a groundbreaking generative augmented reality app for iOS that democratizes AR and VR technology. By leveraging cutting-edge AI, Athena makes immersive experiences accessible to everyone.

## 🚀 Features

- **Generative AR**: Create immersive AR experiences using AI
- **Real-time Processing**: Instant AR content generation
- **User-friendly Interface**: Intuitive controls for seamless creation
- **Cross-device Sync**: Share your AR experiences across devices
- **Community Hub**: Discover and share AR creations

## 📋 Prerequisites

- iOS 15.0+
- Xcode 14.0+
- iPhone with A12 Bionic chip or newer
- CocoaPods

## 🛠 Installation

1. Clone the repository
```bash
git clone https://github.com/minor/athena.git
```

2. Install dependencies
```bash
cd athena
pod install
```

3. Open the workspace
```bash
open Athena.xcworkspace
```

4. Update the `Config.swift` file with your API credentials
```swift
struct Config {
    static let apiURL = "YOUR_BACKEND_URL"
    static let apiKey = "YOUR_API_KEY"
}
```

## 🔧 Configuration

### Backend Setup

The app requires a connection to our backend service. The repo is available [here](https://github.com/minor/athena)


## 📱 Running the App

1. Select your target device in Xcode
2. Press `Cmd + R` to build and run
3. Allow camera and motion sensor permissions when prompted


### Coding Style

We follow the [Swift Style Guide](https://google.github.io/swift/) for consistent code formatting.



## 🙏 Acknowledgments

- ARKit Team at Apple
- [Core ML](https://developer.apple.com/machine-learning/)

