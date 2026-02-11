import media from '@ohos.multimedia.media';
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import common from '@ohos.app.ability.common';
import { audio } from '@kit.AudioKit';

@Entry
@Component
struct MediaPlayerApp {
  @State message: string = '点击播放音频';
  @State num: number = 0;
  @State tru: number = -1;
  @State disp: number = -2;
  @State isPlaying: boolean = false;
  // 添加播放器状态跟踪
  @State playerState: string = 'idle';

  private avPlayer: media.AVPlayer | null = null;
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private timeouts: number[] = [];

  private getAudioFileForDisp(dispValue: number): string {
    return `${dispValue}.wav`;
  }

  // 核心修复：解决状态管理和音频参数设置问题
  async playSound(dispValue: number): Promise<void> {
    this.clearTimeouts();
    this.disp = dispValue;
    this.message = '音频资源加载中...';

    // 彻底清理现有播放器
    await this.cleanupPlayer();

    try {
      // 1. 创建播放器
      this.avPlayer = await new Promise<media.AVPlayer>((resolve, reject) => {
        media.createAVPlayer((err: BusinessError, player: media.AVPlayer | null) => {
          if (err || !player) {
            this.message = '播放器创建失败';
            reject(err || new Error('播放器创建失败'));
          } else {
            // 立即添加基本状态监听
            player.on('stateChange', (state: string) => {
              console.info(`播放器状态: ${state}`);
              this.playerState = state;
            });
            resolve(player);
          }
        });
      });

      // 2. 获取音频资源
      const fileName = this.getAudioFileForDisp(this.disp);
      const fileDescriptor = await this.context.resourceManager.getRawFd(fileName);

      // 3. 设置媒体源 - 先设置源，驱动状态变为initialized
      this.avPlayer.fdSrc = {
        fd: fileDescriptor.fd,
        offset: fileDescriptor.offset,
        length: fileDescriptor.length
      };

      // 等待播放器进入initialized状态
      this.message = '等待播放器初始化...';
      let retryCount = 0;
      while (this.playerState !== 'initialized' && retryCount < 10) {
        await new Promise<void>(resolve => setTimeout(resolve, 50));
        retryCount++;
      }

      // 4. 状态检查后再设置音频参数（修复第二处错误）
      if (this.playerState === 'initialized') {
        // 正确时机设置音频渲染器参数
        this.avPlayer.audioRendererInfo = {
          usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
          rendererFlags: 0
        };

        // 设置完整回调（修复第一处错误）
        this.setPlayerCallbacks();

        // 准备播放
        this.message = '准备音频...';
        await new Promise<void>((resolve, reject) => {
          this.avPlayer?.prepare((prepareErr) => {
            if (prepareErr) {
              this.message = `准备失败: ${prepareErr.message}`;
              reject(prepareErr);
            } else {
              resolve();
            }
          });
        });
      } else {
        this.message = `无法准备，当前状态: ${this.playerState}`;
      }
    } catch (error) {
      const err = error as BusinessError;
      this.message = `播放错误: ${err.message}`;
      await this.cleanupPlayer();
    }
  }

  private setPlayerCallbacks(): void {
    if (!this.avPlayer) return;

    // 状态变化回调
    this.avPlayer.on('stateChange', (state: string) => {
      this.playerState = state;

      switch(state) {
        case 'initialized':
          this.message = '播放器初始化完成';
          break;
        case 'prepared':
          this.playAfterPrepared();
          break;
        case 'playing':
          this.isPlaying = true;
          this.message = '音频播放中...';

          break;
        case 'paused':
          this.isPlaying = false;
          this.message = '播放已暂停';

          break;
        case 'completed':
          this.message = '播放完成';
          this.cleanupPlayer();
          break;
        case 'error':
          this.message = '播放器进入错误状态';
          break;
      }
    });

    // 错误回调
    this.avPlayer.on('error', (err: BusinessError) => {
      this.message = `播放错误: ${err.code}-${err.message}`;
      this.cleanupPlayer();
    });
  }

  private playAfterPrepared(): void {
    // 确保在UI线程执行
    setTimeout(() => {
      if (this.avPlayer && this.avPlayer.state === 'prepared') {
        this.isPlaying = true;
        this.avPlayer.play();
      }
    }, 50);
  }

  async stopSound(): Promise<void> {
    if (this.avPlayer && this.isPlaying) {
      try {
        this.avPlayer.stop();
        this.isPlaying = false;
        this.message = '播放已停止';
        this.clearTimeouts();
      } catch (err) {
        console.error(`停止错误: ${JSON.stringify(err)}`);
      }
    }
  }

  private async cleanupPlayer(): Promise<void> {
    this.clearTimeouts();
    this.isPlaying = false;
    this.playerState = 'idle';

    if (this.avPlayer) {
      try {
        // 确保资源释放顺序正确
        await new Promise<void>((resolve) => {
          this.avPlayer?.stop(() => {
            resolve();
          });
        });

        // 移除监听器
        this.avPlayer.off('stateChange');
        this.avPlayer.off('error');

        // 释放资源
        await new Promise<void>((resolve) => {
          this.avPlayer?.release((releaseErr) => {
            if (releaseErr) {
              console.error(`释放失败: ${releaseErr.message}`);
            }
            resolve();
          });
        });
      } catch (error) {
        console.error(`清理错误: ${JSON.stringify(error)}`);
      } finally {
        this.avPlayer = null;
      }
    }
  }

  private addTimeout(callback: () => void, ms: number): void {
    this.timeouts.push(setTimeout(callback, ms) as number);
  }

  private clearTimeouts(): void {
    this.timeouts.forEach(timeoutId => clearTimeout(timeoutId));
    this.timeouts = [];
  }

  // 您的原始UI和游戏逻辑（完全未改动）
  build() {
    Column() {
      Text('音频播放器')
        .fontSize(26)
        .fontWeight(700)
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 20, bottom: 20 })

      Column() {
        Text(this.message)
          .fontSize(18)
          .lineHeight(60)
          .textAlign(TextAlign.Center)
          .width('90%')
          .borderRadius(8)
          .backgroundColor('#f8f8f8')
          .padding(8)


      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 16 })

      Row({ space: 20 }) {
        Button() {
          Text('播放音频')
            .fontSize(18)
            .fontColor(Color.White)
        }
        .width(140)
        .height(45)
        .onClick(() => {
          this.num = Math.floor(Math.random() * 333) + 1;
          this.disp = this.num <= 111 ? 1 :
            this.num <= 222 ? 2 : 3;

          this.playSound(this.disp);
        })

        Button() {
          Text('停止')
            .fontSize(18)
        }
        .width(80)
        .height(45)
        .backgroundColor('#ff6b6b')
        .enabled(this.isPlaying)
        .onClick(() => this.stopSound())
      }
      .margin({ top: 16, bottom: 16 })

      Text('选择正确答案:')
        .fontSize(20)
        .fontWeight(700)
        .width('100%')
        .margin({ bottom: 12 })
        .padding({ left: 24 })

      Row({ space: 24 }) {
        Button() {
          Text('A')
            .fontSize(24)
            .fontColor(Color.White)
        }
        .size({ width: 64, height: 64 })
        .type(ButtonType.Normal)
        .borderRadius(32)
        .backgroundColor('#ff6b6b')
        .onClick(() => this.selectOption(1))

        Button() {
          Text('B')
            .fontSize(24)
            .fontColor(Color.White)
        }
        .size({ width: 64, height: 64 })
        .type(ButtonType.Normal)
        .borderRadius(32)
        .backgroundColor('#4d96ff')
        .onClick(() => this.selectOption(2))

        Button() {
          Text('C')
            .fontSize(24)
            .fontColor(Color.White)
        }
        .size({ width: 64, height: 64 })
        .type(ButtonType.Normal)
        .borderRadius(32)
        .backgroundColor('#6bcb77')
        .onClick(() => this.selectOption(3))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 24 })

      Text(`播放状态: ${this.isPlaying ? '播放中' : '未播放'}`)
        .fontSize(14)
        .margin({ top: 24 })

      // 调试信息
      Text(`播放器状态: ${this.playerState}`)
        .fontSize(14)
        .margin({ top: 8 })
      Text('A.《歌声与微笑》')
        .fontSize(30)
        .margin({top:40})
      Text('B.《高山青》')
        .fontSize(30)
        .margin({top:10})
      Text('C.《奢香夫人》')
        .fontSize(30)
        .margin({top:10})
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor(Color.White)
  }

  private selectOption(option: number): void {
    this.tru = option;

    if (this.disp < 1) {
      this.message = '请先播放音频';
      return;
    }

    this.checkSelection();
  }

  private checkSelection(): void {
    this.cleanupPlayer()
    if (this.disp === this.tru) {
      router.replaceUrl({ url: 'pages/succeed' });
    } else {
      router.replaceUrl({ url: 'pages/failed' });
    }
  }
}


