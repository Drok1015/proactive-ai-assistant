import { router } from '@kit.ArkUI';
import { TaskCreateRequest } from '../models/ApiModels';
import { getApiClient } from '../network/ApiClient';
import { StorageUtil } from '../utils/StorageUtil';

@Entry
@Component
struct TaskCreate {
  @State taskName: string = '下雨带伞提醒';
  @State latitude: string = '36.0671';
  @State longitude: string = '120.3826';
  @State startHour: number = 8;
  @State endHour: number = 19;
  @State probability: number = 0;
  @State isSubmitting: boolean = false;
  @State errorMsg: string = '';

  private validate(): string {
    if (!this.taskName.trim()) return '请输入任务名称';
    const lat = parseFloat(this.latitude);
    if (isNaN(lat) || lat < -90 || lat > 90) return '纬度范围 -90 到 90';
    const lon = parseFloat(this.longitude);
    if (isNaN(lon) || lon < -180 || lon > 180) return '经度范围 -180 到 180';
    if (this.endHour < this.startHour) return '结束时间不能早于开始时间';
    return '';
  }

  private async submit(): Promise<void> {
    this.errorMsg = this.validate();
    if (this.errorMsg) return;

    this.isSubmitting = true;
    try {
      const backendUrl = await StorageUtil.getInstance().getBackendUrl();
      const client = getApiClient(backendUrl);
      const request: TaskCreateRequest = {
        name: this.taskName.trim(),
        type: 'weather',
        timezone: 'Asia/Shanghai',
        schedule_time: '00:05',
        user_id: 'local-user',
        config: {
          latitude: parseFloat(this.latitude),
          longitude: parseFloat(this.longitude),
          start_hour: this.startHour,
          end_hour: this.endHour,
          precipitation_probability_gt: this.probability,
          title: '带伞提醒',
          body_template: '今天 {hour}:00 有 {probability}% 降雨概率，记得带伞。',
        },
      };
      await client.createTask(request);
      router.back();
    } catch (e) {
      this.errorMsg = '创建失败，请检查网络或参数';
      console.error('Create task failed:', JSON.stringify(e));
    } finally {
      this.isSubmitting = false;
    }
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('← 返回')
          .fontSize(16)
          .fontColor('#315EFB')
          .onClick(() => router.back())
        Text('新建任务')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
          .margin({ left: 'auto' })
      }
      .width('100%')
      .height(56)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 16 }) {
          // 任务名称
          Column({ space: 8 }) {
            Text('任务名称')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#374151')
            TextInput({ text: this.taskName, placeholder: '例如：下雨带伞提醒' })
              .width('100%')
              .height(44)
              .borderRadius(10)
              .backgroundColor('#F9FAFB')
              .onChange((value: string) => { this.taskName = value; })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .shadow({ radius: 6, color: '#08000000', offsetY: 1 })

          // 监控位置
          Column({ space: 8 }) {
            Text('监控位置')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#374151')
            Row({ space: 12 }) {
              TextInput({ text: this.latitude, placeholder: '纬度' })
                .type(InputType.Number)
                .layoutWeight(1)
                .height(44)
                .borderRadius(10)
                .backgroundColor('#F9FAFB')
                .onChange((value: string) => { this.latitude = value; })
              TextInput({ text: this.longitude, placeholder: '经度' })
                .type(InputType.Number)
                .layoutWeight(1)
                .height(44)
                .borderRadius(10)
                .backgroundColor('#F9FAFB')
                .onChange((value: string) => { this.longitude = value; })
            }
            .width('100%')
            Text('常用：北京 39.9,116.4 · 上海 31.2,121.5 · 广州 23.1,113.3 · 青岛 36.07,120.38')
              .fontSize(12)
              .fontColor('#9CA3AF')
              .margin({ top: 4 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .shadow({ radius: 6, color: '#08000000', offsetY: 1 })

          // 检查时间窗口
          Column({ space: 8 }) {
            Text('检查时间窗口')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#374151')
            Row() {
              Text('从').fontSize(14).fontColor('#6B7280')
              Select(this.getHoursOptions())
                .selected(this.startHour)
                .value(`${this.startHour}:00`)
                .width(100)
                .height(36)
                .onSelect((_index: number, value: string) => {
                  this.startHour = _index;
                })
              Text('到').fontSize(14).fontColor('#6B7280').margin({ left: 16 })
              Select(this.getHoursOptions())
                .selected(this.endHour)
                .value(`${this.endHour}:00`)
                .width(100)
                .height(36)
                .onSelect((_index: number, value: string) => {
                  this.endHour = _index;
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            Text('在此时间段内，如果降雨概率超过阈值则触发提醒')
              .fontSize(12)
              .fontColor('#9CA3AF')
              .margin({ top: 4 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .shadow({ radius: 6, color: '#08000000', offsetY: 1 })

          // 降雨概率阈值
          Column({ space: 8 }) {
            Text('降雨概率阈值')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#374151')
            Row() {
              Text(`${this.probability}%`)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor('#315EFB')
                .width(70)
              Slider({
                value: this.probability,
                min: 0,
                max: 100,
                step: 5,
              })
                .layoutWeight(1)
                .selectedColor('#315EFB')
                .onChange((value: number) => {
                  this.probability = value;
                })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            Text(this.probability === 0 ? '任何降雨概率都会提醒' : `降雨概率超过 ${this.probability}% 时提醒`)
              .fontSize(12)
              .fontColor('#9CA3AF')
              .margin({ top: 4 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .alignItems(HorizontalAlign.Start)
          .shadow({ radius: 6, color: '#08000000', offsetY: 1 })

          // 错误提示
          if (this.errorMsg) {
            Text(this.errorMsg)
              .fontSize(14)
              .fontColor('#EF4444')
              .backgroundColor('#FEE2E2')
              .borderRadius(8)
              .padding(12)
              .width('100%')
          }

          // 提交按钮
          Button(this.isSubmitting ? '创建中...' : '创建任务')
            .width('100%')
            .height(50)
            .borderRadius(25)
            .backgroundColor(this.isSubmitting ? '#93C5FD' : '#315EFB')
            .fontColor(Color.White)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .enabled(!this.isSubmitting)
            .onClick(() => this.submit())
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 40 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F4F8')
  }

  private getHoursOptions(): SelectOption[] {
    const options: SelectOption[] = [];
    for (let i = 0; i <= 23; i++) {
      options.push({ value: `${i}:00` } as SelectOption);
    }
    return options;
  }
}
