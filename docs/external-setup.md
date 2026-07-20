# 外部服务接入清单

项目代码可以在未配置第三方账号时启动；此时天气命中会以 `dry-run` 或 `no-device` 写进通知记录，不会误发真实推送。

## 1. 极光推送

1. 在极光控制台创建 HarmonyOS 应用，包名填写 `com.drok.proactiveai`，记录 AppKey 和 Master Secret。
2. 后端本地 `.env` 写入 `JPUSH_APP_KEY`、`JPUSH_MASTER_SECRET`，并在生产环境使用密钥管理服务保存。
3. 在 HarmonyOS ArkTS 工程中接入 `@jg/push` SDK，申请通知权限并初始化 JPush；将 SDK 返回的 registrationId 提交至 `POST /api/v1/devices`，其中 `platform` 固定为 `harmony`。
4. 服务端会把 registrationId 绑定到设备，并通过 JPush REST API 的 `hmos` 平台参数下发通知。
5. 创建天气任务后调用 `POST /api/v1/tasks/{taskId}/run` 验证。通知记录应从 `dry-run` 变为 `sent`。

Master Secret 仅允许出现在后端环境变量和 CI 密钥中，绝不能放进 ArkTS 包、Git 仓库或蒲公英安装包。

## 2. 蒲公英

1. 在蒲公英后台获取 API Key，并保存为 GitHub Repository Secret `PGYER_API_KEY`。
2. 在后端环境变量写入 `PGYER_API_KEY`、`PGYER_APP_KEY`；客户端只调用自有后端，API Key 不会下发到安装包。建立 HarmonyOS `.hap` 安装页，可选配置为 `PGYER_DOWNLOAD_URL` 作为静态回退。
3. 打 `v*` 标签会触发 GitHub Actions：在自托管 DevEco runner 上构建 `.hap`、申请 COS 上传令牌、上传包到蒲公英。当前流水线使用官方快速上传的 `getCOSToken → 上传文件` 流程。
4. GitHub Actions 会轮询蒲公英发布结果。客户端“检查更新”会读取 `/api/v1/app/version/check`，由后端调用蒲公英检测接口并返回不含 API Key 的安装页地址。

## 3. 上线前必须补齐

- 为用户、设备、任务补齐认证和数据隔离；当前 MVP 用 `local-user` 便于单人验证。
- 增加 HTTPS、数据库备份、错误告警、任务超时与重试策略。
- 天气地点采用明确经纬度并在 App 内说明定位用途；不要在未获授权时读取精确位置。
- iOS 面向 App Store 发布时，移除蒲公英更新逻辑，只保留 App Store 版本更新提示。
