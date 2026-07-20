import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'proactive_ai_prefs';
const KEY_BACKEND_URL = 'backend_url';

const DEFAULT_BACKEND_URL = 'https://ruarua520.xyz';

/**
 * 本地持久化存储工具
 */
export class StorageUtil {
  private static instance: StorageUtil | null = null;
  private prefStore: preferences.Preferences | null = null;
  private context: common.UIAbilityContext | null = null;

  static getInstance(): StorageUtil {
    if (!StorageUtil.instance) {
      StorageUtil.instance = new StorageUtil();
    }
    return StorageUtil.instance;
  }

  /**
   * 初始化，需在 Ability onCreate 中调用
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.prefStore = await preferences.getPreferences(context, STORE_NAME);
  }

  /**
   * 获取后端地址
   */
  async getBackendUrl(): Promise<string> {
    if (!this.prefStore) {
      return DEFAULT_BACKEND_URL;
    }
    const value = await this.prefStore.get(KEY_BACKEND_URL, DEFAULT_BACKEND_URL);
    return value as string;
  }

  /**
   * 保存后端地址
   */
  async setBackendUrl(url: string): Promise<void> {
    if (!this.prefStore) {
      return;
    }
    await this.prefStore.put(KEY_BACKEND_URL, url);
    await this.prefStore.flush();
  }
}
