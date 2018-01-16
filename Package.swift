// swift-tools-version:4.0
import PackageDescription

let package = Package(
  name: "RxFeedback",
  products: [
    .library(name: "RxFeedback", targets: ["RxFeedback"])
  ],
  dependencies: [
    .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "4.0.0")),
  ],
  targets: [
    .target(name: "RxFeedback", dependencies: ["RxSwift", "RxCocoa"]),
    .testTarget(name: "RxFeedbackTests", dependencies: ["RxFeedback", "RxSwift", "RxCocoa", "RxBlocking", "RxTest"]),
  ]
)
