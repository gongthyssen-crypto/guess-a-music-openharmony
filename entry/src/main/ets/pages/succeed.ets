import { CircleShape, router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
@Entry
@Component
struct succeed {
  build() {
    Row() {
      Column() {
        Text('you succeed!')
          .fontSize(50)
          .width('120%')
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
          .fontStyle(FontStyle.Italic)
          .margin({
            top: 230
          })
        Button() {
          Text('back')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
        }
        .type(ButtonType.Capsule)
        .margin({
          top: 20
        })
        .size({ width: 200, height: 40 })
        .backgroundColor('#0D9FFB')

        .onClick(()=>{
          console.info('Succeed in clicking return button.')
          try{
            router.replaceUrl({url:'pages/Index'})
            console.info('Succeed in turning into pause page')
          } catch (err) {
            let code = (err as BusinessError).code;
            let message = (err as BusinessError).message;
            console.error(`Failed to return to the pause page. Code is ${code}, message is ${message}`)
          }
        })

      }
    }
  }
}