# tennis-score-ai
基于环境声音的网球场边智能计分助手：球员照常报分或讨论比分，AI 自动理解、规则校验、纠错，并同步到大屏、手机和直播画面。

## macOS 开发

```bash
brew install xcodegen
xcodegen generate
open CourtVoice.xcodeproj
./scripts/macos-acceptance.sh
```

Xcode 工程由 XcodeGen 生成，不要手改 `CourtVoice.xcodeproj`。当前仓库仍是工程集成里程碑，在真机音频、StoreKit Sandbox、签名和 TestFlight 完成前，不要把它称为 App Store 可发布版本。
