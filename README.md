# Proactive AI Assistant

一个以“条件命中才提醒”为核心的移动端主动式 AI 项目。首期实现天气带伞提醒，并预留油价、日程和设备状态等任务类型。

## 架构

- `harmony/`：HarmonyOS NEXT 原生 ArkTS 客户端，查看任务、创建天气提醒、查看通知记录。
- `backend/`：FastAPI 服务。后端定时检测 Open-Meteo 数据、去重并发送推送。
- `PushProvider`：推送渠道适配层；未配置密钥时使用安全的 dry-run，配置极光凭证后切换为真实推送。
- `Version API`：客户端只访问自己的后端，后端返回蒲公英下载页。蒲公英 API Key 仅应放在 CI 中。

## 首期规则

每天在指定时间检查天气；只要当天指定时段内任一小时的降雨概率大于阈值，就推送一次。默认规则为北京时间 08:00–19:00、降雨概率 `> 0%`、其余情况静默。

## 本地启动后端

```bash
cd backend
cp .env.example .env
python3 -m venv .venv
.venv/bin/pip install -e '.[dev]'
.venv/bin/uvicorn app.main:app --reload --port 8000
```

打开 `http://127.0.0.1:8000/docs` 可调试接口。先 `POST /api/v1/devices` 注册设备，再创建任务或调用 `POST /api/v1/tasks/{id}/run` 验证链路。

## 推送接入

设置以下环境变量即可启用极光；不要把它们写进 App 或提交进 Git：

```bash
JPUSH_APP_KEY=...
JPUSH_MASTER_SECRET=...
```

客户端原生层注册极光后，把 `registrationId` 提交到 `POST /api/v1/devices`。未配置凭证时，服务会完整记录通知，但不会对真实设备发送。

## 蒲公英发布

`.github/workflows/pgyer-harmony.yml` 是 HarmonyOS `.hap` 构建并上传蒲公英的模板；运行环境必须是已安装 DevEco Studio/HarmonyOS SDK 的 self-hosted runner。需要在 GitHub Secrets 配置：

- `PGYER_API_KEY`

还需要在后端设置 `PGYER_API_KEY`、`PGYER_APP_KEY`（均只保存在服务端），客户端会经由后端检查蒲公英新版本并跳转安装页。若尚未配置，可先用 `PGYER_DOWNLOAD_URL` 提供静态下载入口。HarmonyOS 客户端发现新版本后跳转蒲公英安装页，由用户确认下载和安装。

## HarmonyOS 本地签名

`harmony/build-profile.json5` 会由 DevEco Studio 写入本机调试证书路径和密码，已被 Git 忽略。首次克隆后可复制 `harmony/build-profile.json5.example` 为该文件，再在 DevEco Studio 的“项目结构 → 签名配置”中生成本机调试签名。

## 当前限制

HarmonyOS 目标采用 ArkTS/ArkUI，而不是 Android APK。需在 DevEco Studio 中打开 `harmony/`，完成签名和 HarmonyOS SDK 配置后构建 `.hap`。原生极光 SDK 和真实蒲公英账号凭证需在获得账号后配置。此前的 `mobile/` Flutter 目录仅保留为已废弃原型，不参与发布。
