import { router, window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { Task, NotificationLog } from '../models/ApiModels';
import { getApiClient } from '../network/ApiClient';
import { StorageUtil } from '../utils/StorageUtil';

interface TabItem {
  title: string;
  icon: string;
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State tasks: Task[] = [];
  @State notifications: NotificationLog[] = [];
  @State backendUrl: string = 'http://10.0.2.2:8000';
  @State isLoading: boolean = false;
  @State isConnected: boolean = false;
  @State toastMsg: string = '';
  @State topSafeArea: number = 0;
  // 在全面屏设备上为系统导航指示条预留空间，避免底部 TabBar 被遮挡。
  @State bottomSafeArea: number = 0;

  private tabs: TabItem[] = [
    { title: '任务', icon: '📋' },
    { title: '通知', icon: '🔔' },
    { title: '设置', icon: '⚙' },
  ];

  async aboutToAppear(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    await this.initBottomSafeArea(context);
    await StorageUtil.getInstance().init(context);
    this.backendUrl = await StorageUtil.getInstance().getBackendUrl();
    await this.loadData();
  }

  private async initBottomSafeArea(context: common.UIAbilityContext): Promise<void> {
    try {
      const mainWindow = await context.windowStage.getMainWindow();
      const updateSystemSafeArea = (area: window.AvoidArea): void => {
        this.topSafeArea = this.getUIContext().px2vp(area.topRect.height);
        this.bottomSafeArea = this.getUIContext().px2vp(area.bottomRect.height);
      };

      updateSystemSafeArea(mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM));
      mainWindow.on('avoidAreaChange', (options: window.AvoidAreaOptions) => {
        if (options.type === window.AvoidAreaType.TYPE_SYSTEM) {
          updateSystemSafeArea(options.area);
        }
      });
    } catch (e) {
      // 未获取到避让区时保留原有布局，不影响应用启动。
      console.error('Failed to get system avoid area:', JSON.stringify(e));
    }
  }

  private async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      const client = getApiClient(this.backendUrl);
      this.isConnected = await client.healthCheck();
      if (this.isConnected) {
        this.tasks = await client.listTasks();
      }
    } catch (e) {
      this.isConnected = false;
      console.error('Failed to load data:', JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  private async loadNotifications(): Promise<void> {
    try {
      const client = getApiClient(this.backendUrl);
      this.notifications = await client.listNotifications();
    } catch (e) {
      console.error('Failed to load notifications:', JSON.stringify(e));
    }
  }

  private async toggleTask(task: Task): Promise<void> {
    try {
      const client = getApiClient(this.backendUrl);
      await client.updateTask(task.id, { enabled: !task.enabled });
      this.tasks = await client.listTasks();
    } catch (e) {
      console.error('Failed to toggle task:', JSON.stringify(e));
    }
  }

  private async runTask(task: Task): Promise<void> {
    try {
      const client = getApiClient(this.backendUrl);
      await client.runTask(task.id);
      this.toastMsg = '任务已触发';
    } catch (e) {
      this.toastMsg = '触发失败';
    }
  }

  private getStatusText(status: string): string {
    if (status === 'sent') return '已发送';
    if (status === 'dry-run') return '模拟发送';
    if (status === 'no-device') return '无设备';
    return status;
  }

  private getStatusColor(status: string): ResourceColor {
    if (status === 'sent') return '#059669';
    if (status === 'dry-run') return '#D97706';
    if (status === 'no-device') return '#9CA3AF';
    return '#6B7280';
  }

  private formatDate(isoString: string): string {
    try {
      const d = new Date(isoString);
      const m = (d.getMonth() + 1).toString().padStart(2, '0');
      const day = d.getDate().toString().padStart(2, '0');
      const h = d.getHours().toString().padStart(2, '0');
      const min = d.getMinutes().toString().padStart(2, '0');
      return `${m}-${day} ${h}:${min}`;
    } catch {
      return isoString;
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text('主动 AI')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D2A70')
        if (!this.isConnected) {
          Text('离线')
            .fontSize(12)
            .fontColor('#EF4444')
            .backgroundColor('#FEE2E2')
            .borderRadius(8)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .margin({ left: 8 })
        }
      }
      .width('100%')
      .height(56)
      .margin({ top: this.topSafeArea })
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)

      Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
        // 任务列表
        TabContent() {
          this.TaskListBuilder()
        }
        .tabBar(this.TabBarItem(0))

        // 通知历史
        TabContent() {
          this.NotificationListBuilder()
        }
        .tabBar(this.TabBarItem(1))

        // 设置
        TabContent() {
          this.SettingsBuilder()
        }
        .tabBar(this.TabBarItem(2))
      }
      .onChange((index: number) => {
        this.currentIndex = index;
        if (index === 1) {
          this.loadNotifications();
        }
      })
      .barWidth('100%')
      .barHeight(56)
      .layoutWeight(1)
      .margin({ bottom: this.bottomSafeArea })
      .scrollable(false)
      .animationDuration(0)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F8')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  TabBarItem(index: number) {
    Column() {
      Text(this.tabs[index].icon)
        .fontSize(20)
      Text(this.tabs[index].title)
        .fontSize(11)
        .fontColor(this.currentIndex === index ? '#315EFB' : '#9CA3AF')
        .margin({ top: 2 })
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ==================== 任务列表 ====================
  @Builder
  TaskListBuilder() {
    Column() {
      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#9CA3AF')
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.tasks.length === 0) {
        Column() {
          Text('📭').fontSize(48)
          Text('暂无任务')
            .fontSize(16)
            .fontColor('#9CA3AF')
            .margin({ top: 12 })
          Text('点击下方按钮创建第一个任务')
            .fontSize(13)
            .fontColor('#D1D5DB')
            .margin({ top: 4 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.tasks, (task: Task) => {
            ListItem() {
              this.TaskCard(task)
            }
          }, (task: Task) => task.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 16 })
      }

      Button('新建主动任务')
        .width('90%')
        .height(48)
        .borderRadius(24)
        .backgroundColor('#315EFB')
        .fontColor(Color.White)
        .fontSize(16)
        .margin({ bottom: 16, top: 8 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/TaskCreate' }).then(() => {
            this.loadData();
          });
        })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TaskCard(task: Task) {
    Row() {
      Text(task.type === 'weather' ? '☂' : '📌')
        .fontSize(28)
        .fontColor('#315EFB')

      Column() {
        Text(task.name)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text(`每天 ${task.schedule_time} 检查`)
            .fontSize(13)
            .fontColor('#6B7280')
          if (task.type === 'weather') {
            Text(` · ${task.config.start_hour}:00-${task.config.end_hour}:00 有雨提醒`)
              .fontSize(13)
              .fontColor('#6B7280')
          }
        }
        .margin({ top: 4 })

        Row({ space: 8 }) {
          Text(task.enabled ? '已启用' : '已禁用')
            .fontSize(12)
            .fontColor(task.enabled ? '#059669' : '#9CA3AF')
            .backgroundColor(task.enabled ? '#ECFDF5' : '#F3F4F6')
            .borderRadius(6)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .margin({ top: 6 })

          Text('立即执行')
            .fontSize(12)
            .fontColor('#315EFB')
            .backgroundColor('#EFF6FF')
            .borderRadius(6)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .margin({ top: 6 })
            .onClick(() => this.runTask(task))
        }
      }
      .layoutWeight(1)
      .margin({ left: 14 })
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: task.enabled })
        .selectedColor('#315EFB')
        .onChange(() => this.toggleTask(task))
    }
    .width('100%')
    .padding(18)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })
  }

  // ==================== 通知列表 ====================
  @Builder
  NotificationListBuilder() {
    Column() {
      if (this.notifications.length === 0) {
        Column() {
          Text('🔔').fontSize(48)
          Text('暂无通知记录')
            .fontSize(16)
            .fontColor('#9CA3AF')
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.notifications, (log: NotificationLog) => {
            ListItem() {
              this.NotificationCard(log)
            }
          }, (log: NotificationLog) => log.id)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 16, right: 16, top: 16 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  NotificationCard(log: NotificationLog) {
    Column() {
      Row() {
        Text(log.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.getStatusText(log.status))
          .fontSize(12)
          .fontColor(this.getStatusColor(log.status))
          .backgroundColor(log.status === 'sent' ? '#ECFDF5' : log.status === 'dry-run' ? '#FFFBEB' : '#F3F4F6')
          .borderRadius(6)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }

      Text(log.body)
        .fontSize(14)
        .fontColor('#4B5563')
        .margin({ top: 6 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.formatDate(log.created_at))
        .fontSize(12)
        .fontColor('#9CA3AF')
        .margin({ top: 6 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
    .shadow({ radius: 6, color: '#08000000', offsetY: 1 })
  }

  // ==================== 设置 ====================
  @Builder
  SettingsBuilder() {
    Column({ space: 16 }) {
      // 后端连接
      Column({ space: 12 }) {
        Text('后端连接')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')

        Text(this.isConnected ? '● 已连接' : '● 未连接')
          .fontSize(14)
          .fontColor(this.isConnected ? '#059669' : '#EF4444')

        TextInput({ text: this.backendUrl, placeholder: '后端地址' })
          .width('100%')
          .height(44)
          .borderRadius(10)
          .backgroundColor(Color.White)
          .onChange((value: string) => {
            this.backendUrl = value;
          })

        Row({ space: 12 }) {
          Button('保存')
            .layoutWeight(1)
            .height(40)
            .borderRadius(10)
            .backgroundColor('#315EFB')
            .fontColor(Color.White)
            .onClick(async () => {
              await StorageUtil.getInstance().setBackendUrl(this.backendUrl);
              await this.loadData();
            })

          Button('测试连接')
            .layoutWeight(1)
            .height(40)
            .borderRadius(10)
            .backgroundColor('#F3F4F6')
            .fontColor('#374151')
            .onClick(async () => {
              const client = getApiClient(this.backendUrl);
              this.isConnected = await client.healthCheck();
            })
        }
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius(16)
      .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })

      // 关于
      Column({ space: 12 }) {
        Text('关于')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')

        Row() {
          Text('版本').fontSize(14).fontColor('#6B7280')
          Text('0.1.0').fontSize(14).fontColor('#1F2937').margin({ left: 'auto' })
        }
        .width('100%')

        Divider()

        Text('条件命中才提醒，不打扰是默认。')
          .fontSize(13)
          .fontColor('#9CA3AF')
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      .width('100%')
      .padding(18)
      .backgroundColor(Color.White)
      .borderRadius(16)
      .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}
