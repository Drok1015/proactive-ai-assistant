import { http } from '@kit.NetworkKit';
import {
  Task,
  TaskCreateRequest,
  TaskPatchRequest,
  NotificationLog,
  DeviceCreateRequest,
  DeviceRegisterResponse,
  VersionCheckResponse,
} from '../models/ApiModels';

const DEFAULT_BASE_URL = 'http://10.0.2.2:8000';

class EmptyPayload {
}

/**
 * HTTP API 客户端，与后端 FastAPI 通信
 */
export class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string = DEFAULT_BASE_URL) {
    this.baseUrl = baseUrl.replace(/\/+$/, '');
  }

  getBaseUrl(): string {
    return this.baseUrl;
  }

  /**
   * 通用 GET 请求
   */
  private async doGet<T>(path: string): Promise<T> {
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(`${this.baseUrl}${path}`, {
        method: http.RequestMethod.GET,
        header: { 'Content-Type': 'application/json' },
        readTimeout: 15000,
        connectTimeout: 10000,
      });
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
      }
      throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 通用 POST 请求
   */
  private async doPost<T>(path: string, body: object): Promise<T> {
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(`${this.baseUrl}${path}`, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(body),
        readTimeout: 15000,
        connectTimeout: 10000,
      });
      if (response.responseCode >= 200 && response.responseCode < 300) {
        const result = response.result as string;
        return result ? JSON.parse(result) as T : null as T;
      }
      throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 通用更新请求。当前 HarmonyOS HttpKit 未提供 PATCH 枚举，使用兼容的 PUT。
   */
  private async doPatch<T>(path: string, body: object): Promise<T> {
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(`${this.baseUrl}${path}`, {
        method: http.RequestMethod.PUT,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(body),
        readTimeout: 15000,
        connectTimeout: 10000,
      });
      if (response.responseCode >= 200 && response.responseCode < 300) {
        return JSON.parse(response.result as string) as T;
      }
      throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
    } finally {
      httpRequest.destroy();
    }
  }

  // ---- 任务 API ----

  async listTasks(): Promise<Task[]> {
    return this.doGet<Task[]>('/api/v1/tasks');
  }

  async createTask(task: TaskCreateRequest): Promise<Task> {
    return this.doPost<Task>('/api/v1/tasks', task);
  }

  async updateTask(taskId: string, patch: TaskPatchRequest): Promise<Task> {
    return this.doPatch<Task>(`/api/v1/tasks/${taskId}`, patch);
  }

  async runTask(taskId: string): Promise<NotificationLog | null> {
    return this.doPost<NotificationLog | null>(`/api/v1/tasks/${taskId}/run`, new EmptyPayload());
  }

  // ---- 通知 API ----

  async listNotifications(): Promise<NotificationLog[]> {
    return this.doGet<NotificationLog[]>('/api/v1/notifications');
  }

  // ---- 设备 API ----

  async registerDevice(device: DeviceCreateRequest): Promise<DeviceRegisterResponse> {
    return this.doPost<DeviceRegisterResponse>('/api/v1/devices', device);
  }

  // ---- 版本 API ----

  async checkVersion(version: string): Promise<VersionCheckResponse> {
    return this.doGet<VersionCheckResponse>(`/api/v1/app/version/check?version=${encodeURIComponent(version)}`);
  }

  // ---- 健康检查 ----

  async healthCheck(): Promise<boolean> {
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(`${this.baseUrl}/health`, {
        method: http.RequestMethod.GET,
        readTimeout: 5000,
        connectTimeout: 5000,
      });
      httpRequest.destroy();
      return response.responseCode === 200;
    } catch {
      return false;
    }
  }
}

// 全局单例
let globalClient: ApiClient | null = null;

export function getApiClient(baseUrl: string = DEFAULT_BASE_URL): ApiClient {
  if (!globalClient || globalClient.getBaseUrl() !== baseUrl) {
    globalClient = new ApiClient(baseUrl);
  }
  return globalClient;
}
