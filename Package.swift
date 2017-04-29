import PackageDescription

let package = Package(
    name: "RxFeedback",
    targets: [
        Target(name: "RxFeedback", dependencies: [])
    ],
    dependencies: [
        .Package(url: "https://github.com/ReactiveX/RxSwift.git", majorVersion: 3)
    ]
)
