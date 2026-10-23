# chubby-cat：自行分发与可选公证

## 当前开发与分发方式

现阶段采用**自行分发预览版**：开发者直接提供 ZIP，不通过 Mac App Store。默认预览版使用本机 ad-hoc 签名，尚未使用 Developer ID 签名或经过 Apple 公证；构建、打包不需要 Apple Developer Program 会员或 Apple 账号凭据。

“自行分发”描述的是提供软件的渠道；“签名 / 公证”描述的是系统验证状态。是否付费不能用来判断软件分发是否合法，仍需遵守适用的软件和素材许可等要求。Apple 官方文档也区分[不同分发方式](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)。

## 默认：打包自行分发预览版

在项目根目录运行：

```bash
bash scripts/release.sh --check
bash scripts/release.sh
```

默认版本是 0.2.0；要发下一版，可设置 `APP_VERSION=0.2.1 BUILD_NUMBER=3 bash scripts/release.sh`。已有同名包不会被静默覆盖。

产物示例：

```text
dist/previews/chubby-cat-0.2.0-preview-macos-arm64.zip
dist/previews/chubby-cat-0.2.0-preview-macos-arm64.zip.sha256
```

ZIP 包含 `chubby-cat.app`、`INSTALL.txt` 和 `distribution.json`。说明文件和元数据会明确标注 `ad-hoc`、`notarized: false`，不会宣称经过 Apple 认证。用户解压后可将应用拖到 `/Applications`；macOS 可能阻止默认启动。仅在确认来源可信后，由用户自行按 [Apple 的应用安全说明](https://support.apple.com/102445)决定是否继续，不附带关闭 Gatekeeper 或清除 quarantine 的安装脚本。

这是 Apple Silicon / macOS 14+ 的预览包，跨机器验证仍需继续，不保证所有系统管理策略允许打开。打包不会自动上传或发布到外部服务，也没有加入应用自动更新功能。

## 可选：Developer ID 签名与 Apple 公证

这一条路径用于改善默认安全设置下的安装体验，保留现有签名、公证、票据和 Gatekeeper 检查。需要有效 Apple Developer Program 资格、Developer ID Application 证书及对应私钥、公证凭据。未配置这些条件不影响默认预览版打包。

以下证书配置步骤仅在选择该可选路径时需要。

## 1. 可选路径：在本机生成并安装 Developer ID Application 证书

1. 打开 macOS **钥匙串访问**，菜单中选择 **证书助理 → 从证书颁发机构请求证书**。填写你的开发者邮箱和名称，选择保存到磁盘，生成 CSR；私钥留在这台 Mac 的钥匙串。
2. 登录 [Apple Developer 的证书管理](https://developer.apple.com/account/resources/certificates/list)。创建 **Developer ID Application** 证书，上传刚生成的 CSR，按网站流程下载 `.cer` 后双击导入钥匙串。不要选成 Apple Development、Apple Distribution 或 Developer ID Installer。
3. 在钥匙串的“我的证书”中确认该证书可展开，并带有对应私钥。只有公开证书而没有私钥不能签名。如果团队账号没有创建权限，请让 Account Holder / Admin 按 Apple 当前角色权限协助；个人账号通常由持有人操作。
4. 在终端检查：

```bash
security find-identity -v -p codesigning
```

记下完整的 `Developer ID Application: 你的名称 (TEAMID)` 身份名称。不要把私钥、`.p12` 或钥匙串密码发送到聊天或提交到仓库。

Apple 官方说明：[Developer ID 证书](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)、[创建 CSR](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request)。

## 2. 可选路径：将公证凭据保存到本机钥匙串

从 Apple 账号管理页面为 notarytool 创建专用密码，然后在终端运行交互命令：

```bash
xcrun notarytool store-credentials "chubby-cat-notary"
```

按提示在终端输入 Apple ID、Team ID 和 App 专用密码；凭据保存在系统钥匙串中，不要写进脚本或 README。工具也支持 App Store Connect API Key，团队已有该方式时可以按官方文档使用。

如 Xcode 弹出尚未接受的许可协议，请你自行阅读、决定并完成；构建脚本不会代为接受。当前本机构建使用 Command Line Tools。

## 3. 可选路径：生成已公证分发包

在项目根目录设置非敏感的证书名称和钥匙串 profile 名：

```bash
export SIGNING_IDENTITY='Developer ID Application: 你的名称 (TEAMID)'
export NOTARY_PROFILE='chubby-cat-notary'
export APP_VERSION='0.2.0'
export BUILD_NUMBER='2'

bash scripts/release.sh --notarized --check
bash scripts/release.sh --notarized
```

`--notarized --check` 检查本机工具、证书及环境变量；真正发布时才向 Apple 验证 profile 并提交应用。签名过程可能由 macOS 请求访问私钥，请仅对你确认的签名操作授权。

流程会运行测试、构建优化的 arm64 应用、使用 Hardened Runtime 和安全时间戳签名，再通过 notarytool 提交 Apple。只有结果为 `Accepted`，才会 staple / validate 票据并执行 `spctl` 检查；最终 ZIP 在附加票据之后重新生成，同时输出 SHA-256 和公证结果记录。

成功后产物：

```text
dist/releases/chubby-cat-0.2.0-macos-arm64.zip
dist/releases/chubby-cat-0.2.0-macos-arm64.zip.sha256
dist/releases/chubby-cat-0.2.0-macos-arm64.zip.notary.json
```

可选公证路径失败时不会自动改发预览包，也不会将未公证包标记为已公证。`dist/release-staging/` 是工作目录，其中的文件不用于分发。若公证失败，查看 `notary-result.json` 的提交 ID，通过 `xcrun notarytool log 提交ID --keychain-profile chubby-cat-notary 日志文件.json` 获取原因，修复后重新提交。同一个版本的已公证 ZIP 不会被静默覆盖。

官方流程：[Apple 公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[自定义公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)。

## 4. 已公证包的安装与跨机器实测

下载已公证路径生成的 ZIP，解压后把 `chubby-cat.app` 拖到 `/Applications` 再启动。首发包只面向 Apple Silicon Mac，最低目标为 macOS 14；Intel 版本不在此包内。发布前仍应在另一台兼容 Mac 上，用浏览器下载获得 quarantine 标记的原始 ZIP 实测安装、启动、钥匙串和登录启动功能。

用户不需要付费开发者账号。已公证包如果无法正常验证，先调查签名、公证或系统策略问题，不将关闭系统安全保护作为安装前提。

## 图标

图标源稿：`assets/icon/app-icon-v1.png`，以用户提供的小猫形象生成。`scripts/build-icon.sh` 使用 macOS 的 sips / iconutil 生成十种尺寸的 ICNS 表示；打包时写入 `CFBundleIconFile`，并给应用 About 面板设置相同图标。菜单栏仍使用易读的单色猫符号。
