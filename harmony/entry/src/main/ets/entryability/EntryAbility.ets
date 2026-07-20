import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {}

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.getMainWindow().then(async (mainWindow: window.Window) => {
      await mainWindow.setWindowLayoutFullScreen(true);
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#F3F4F8',
        statusBarContentColor: '#1D2A70',
        navigationBarColor: '#F3F4F8',
        navigationBarContentColor: '#9CA3AF'
      });
    }).catch((error: Error) => {
      console.error(`Failed to set system bar colors: ${JSON.stringify(error)}`);
    });

    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        console.error(`Failed to load home page: ${JSON.stringify(error)}`);
      }
    });
  }
}
