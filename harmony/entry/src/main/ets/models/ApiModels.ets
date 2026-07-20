/**
 * 天气任务配置
 */
export interface WeatherConfig {
  latitude: number;
  longitude: number;
  start_hour: number;
  end_hour: number;
  precipitation_probability_gt: number;
  title: string;
  body_template: string;
}

/**
 * 主动任务
 */
export interface Task {
  id: string;
  name: string;
  type: string;
  enabled: boolean;
  timezone: string;
  schedule_time: string;
  config: WeatherConfig;
}

/**
 * 创建任务请求
 */
export interface TaskCreateRequest {
  name: string;
  type: string;
  timezone: string;
  schedule_time: string;
  user_id: string;
  config: WeatherConfig;
}

/**
 * 更新任务请求
 */
export interface TaskPatchRequest {
  name?: string;
  enabled?: boolean;
  schedule_time?: string;
  config?: WeatherConfig;
}

/**
 * 通知日志
 */
export interface NotificationLog {
  id: string;
  task_id: string;
  event_key: string;
  title: string;
  body: string;
  status: string;
  provider_response: object;
  created_at: string;
}

/**
 * 设备注册请求
 */
export interface DeviceCreateRequest {
  platform: string;
  registration_id: string;
  push_provider: string;
  user_id: string;
}

/**
 * 设备注册响应
 */
export interface DeviceRegisterResponse {
  id: string;
  enabled: boolean;
}

/**
 * 版本检查响应
 */
export interface VersionCheckResponse {
  hasUpdate: boolean;
  forceUpdate?: boolean;
  version: string;
  build: number;
  downloadUrl?: string;
  description?: string;
  mode: string;
}
