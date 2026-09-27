import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { FoodRecord } from '../model/NutritionModels';
import { FoodRecordStore } from '../service/FoodRecordStore';
import { NutritionDateUtils } from '../service/NutritionDateUtils';

interface NutritionDetailParams {
  dayKey?: string;
}

@Entry
@Component
struct NutritionDetailPage {
  @State records: FoodRecord[] = [];
  @State selectedDayKey: string = '';
  @State selectedMeal: number = 3;
  @State vitaminsExpanded: boolean = false;
  @State mineralsExpanded: boolean = false;
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const params: NutritionDetailParams = router.getParams() as NutritionDetailParams;
    this.selectedDayKey = params !== undefined && params.dayKey !== undefined ?
      params.dayKey : NutritionDateUtils.getDayKey();
    this.loadRecords();
  }

  onPageShow(): void {
    if (this.selectedDayKey.length === 0) {
      this.selectedDayKey = NutritionDateUtils.getDayKey();
    }
    this.loadRecords();
  }

  async loadRecords(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.records = await FoodRecordStore.getByDay(context, this.selectedDayKey);
    } catch (error) {
      console.error(`load nutrition detail failed: ${JSON.stringify(error)}`);
    }
  }

  getVisibleRecords(): FoodRecord[] {
    if (this.selectedMeal === 3) return this.records;
    return this.records.filter((record: FoodRecord) => record.mealIndex === this.selectedMeal);
  }

  getNutrientValue(key: string): number {
    let total: number = 0;
    this.getVisibleRecords().forEach((record: FoodRecord) => {
      if (key === 'calories') total += record.energyKCal;
      else if (key === 'protein') total += record.protein;
      else if (key === 'fat') total += record.fat;
      else if (key === 'carbohydrate') total += record.carbohydrate;
      else if (key === 'dietaryFiber') total += record.dietaryFiber;
      else if (key === 'cholesterol') total += record.cholesterol;
      else if (key === 'vitaminA') total += record.vitaminA;
      else if (key === 'vitaminB1') total += record.thiamin;
      else if (key === 'vitaminB2') total += record.riboflavin;
      else if (key === 'vitaminC') total += record.vitaminC;
      else if (key === 'vitaminE') total += record.vitaminETotal;
      else if (key === 'calcium') total += record.calcium;
      else if (key === 'phosphorus') total += record.phosphorus;
      else if (key === 'potassium') total += record.potassium;
      else if (key === 'sodium') total += record.sodium;
      else if (key === 'magnesium') total += record.magnesium;
      else if (key === 'iron') total += record.iron;
      else if (key === 'zinc') total += record.zinc;
      else if (key === 'selenium') total += record.selenium;
      else if (key === 'copper') total += record.copper;
      else if (key === 'manganese') total += record.manganese;
    });
    return key === 'calories' ? Math.round(total) : Math.round(total * 10) / 10;
  }

  getSelectedMealName(): string {
    if (this.selectedMeal === 0) return '早餐🌅摄入';
    if (this.selectedMeal === 1) return '午餐☀️摄入';
    if (this.selectedMeal === 2) return '晚餐🌙摄入';
    return '全天摄入';
  }

  getSelectedDayLabel(): string {
    const parts: string[] = this.selectedDayKey.split('-');
    if (parts.length < 3) return this.selectedDayKey;
    return `${parts[0]}年${parts[1]}月${parts[2]}日`;
  }

  handleSwipeBack(): void {
    router.back();
  }

  handleCrownScroll(event: CrownEvent): void {
    if (event.action !== CrownAction.UPDATE) return;
    this.pageScroller.scrollBy(0, -event.degree * 2.5);
    event.stopPropagation();
  }

  @Builder
  mealSelector(index: number, title: string) {
    Text(title)
      .fontSize(8)
      .fontColor(this.selectedMeal === index ? '#092117' : '#C9D2CD')
      .padding({ top: 5, right: 5, bottom: 5, left: 5 })
      .backgroundColor(this.selectedMeal === index ? '#67D89A' : '#202A26')
      .borderRadius(12)
      .onClick(() => {
        this.selectedMeal = index;
      })
  }

  @Builder
  primaryNutrient(label: string, key: string, unit: string, color: string) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(8)
        .fontColor('#8F9B95')
      Text(`${this.getNutrientValue(key)} ${unit}`)
        .fontSize(9)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
        .maxLines(1)
    }
    .width(72)
    .height(34)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#18211E')
    .borderRadius(13)
  }

  @Builder
  nutrientDetailRow(label: string, key: string, unit: string) {
    Row() {
      Text(label)
        .fontSize(9)
        .fontColor('#AAB5AF')
        .layoutWeight(1)
      Text(`${this.getNutrientValue(key)} ${unit}`)
        .fontSize(9)
        .fontColor('#E1E7E3')
    }
    .width('100%')
    .height(22)
    .padding({ left: 10, right: 10 })
    .backgroundColor('#18211E')
    .borderRadius(11)
  }

  private showExpandedContent(scrollDistance: number): void {
    setTimeout(() => {
      this.pageScroller.scrollBy(0, scrollDistance);
    }, 80);
  }

  @Builder
  vitaminCategory() {
    Column({ space: 3 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          Column({ space: 1 }) {
            Text('维生素')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor('#F4F7F5')
            Text(this.vitaminsExpanded ? '点击收起详细数据' : '点击展开 A、B1、B2、C、E')
              .fontSize(8)
              .fontColor('#B8C2BD')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text(this.vitaminsExpanded ? '▲' : '▼')
            .fontSize(9)
            .fontColor('#67D89A')
        }
        .width('100%')
        .padding({ left: 10, right: 10 })
      }
      .width('100%')
      .height(40)
      .padding(0)
      .backgroundColor('#18211E')
      .borderRadius(15)
      .onClick(() => {
        this.vitaminsExpanded = !this.vitaminsExpanded;
        if (this.vitaminsExpanded) {
          this.mineralsExpanded = false;
          this.showExpandedContent(55);
        }
      })

      if (this.vitaminsExpanded) {
        this.nutrientDetailRow('维生素 A', 'vitaminA', 'μg RAE')
        this.nutrientDetailRow('维生素 B1', 'vitaminB1', 'mg')
        this.nutrientDetailRow('维生素 B2', 'vitaminB2', 'mg')
        this.nutrientDetailRow('维生素 C', 'vitaminC', 'mg')
        this.nutrientDetailRow('维生素 E', 'vitaminE', 'mg')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  mineralCategory() {
    Column({ space: 3 }) {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Row() {
          Column({ space: 1 }) {
            Text('矿物质')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor('#F4F7F5')
            Text(this.mineralsExpanded ? '点击收起详细数据' : '点击展开钙、磷、钾、钠等 10 项')
              .fontSize(8)
              .fontColor('#B8C2BD')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text(this.mineralsExpanded ? '▲' : '▼')
            .fontSize(9)
            .fontColor('#67D89A')
        }
        .width('100%')
        .padding({ left: 10, right: 10 })
      }
      .width('100%')
      .height(40)
      .padding(0)
      .backgroundColor('#18211E')
      .borderRadius(15)
      .onClick(() => {
        this.mineralsExpanded = !this.mineralsExpanded;
        if (this.mineralsExpanded) {
          this.vitaminsExpanded = false;
          this.showExpandedContent(100);
        }
      })

      if (this.mineralsExpanded) {
        this.nutrientDetailRow('钙', 'calcium', 'mg')
        this.nutrientDetailRow('磷', 'phosphorus', 'mg')
        this.nutrientDetailRow('钾', 'potassium', 'mg')
        this.nutrientDetailRow('钠', 'sodium', 'mg')
        this.nutrientDetailRow('镁', 'magnesium', 'mg')
        this.nutrientDetailRow('铁', 'iron', 'mg')
        this.nutrientDetailRow('锌', 'zinc', 'mg')
        this.nutrientDetailRow('硒', 'selenium', 'μg')
        this.nutrientDetailRow('铜', 'copper', 'mg')
        this.nutrientDetailRow('锰', 'manganese', 'mg')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column({ space: 4 }) {
      Text('营养详情')
        .width('70%')
        .height(28)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)

      if (this.selectedDayKey !== NutritionDateUtils.getDayKey()) {
        Text(this.getSelectedDayLabel())
          .fontSize(8)
          .fontColor('#AAB5AF')
      }

      Row({ space: 3 }) {
        this.mealSelector(0, '早餐🌅')
        this.mealSelector(1, '午餐☀️')
        this.mealSelector(2, '晚餐🌙')
        this.mealSelector(3, '全天')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Text(this.getSelectedMealName())
        .fontSize(9)
        .fontColor('#67D89A')

      Scroll(this.pageScroller) {
        Column({ space: 5 }) {
          Row({ space: 4 }) {
            this.primaryNutrient('总热量', 'calories', 'kcal', '#F5C96A')
            this.primaryNutrient('蛋白质', 'protein', 'g', '#E1E7E3')
          }
          Row({ space: 4 }) {
            this.primaryNutrient('脂肪', 'fat', 'g', '#E1E7E3')
            this.primaryNutrient('碳水化合物', 'carbohydrate', 'g', '#E1E7E3')
          }
          Row({ space: 4 }) {
            this.primaryNutrient('胆固醇', 'cholesterol', 'mg', '#E1E7E3')
            this.primaryNutrient('膳食纤维', 'dietaryFiber', 'g', '#E1E7E3')
          }

          this.vitaminCategory()
          this.mineralCategory()

          if (this.getVisibleRecords().length === 0) {
            Text('当前餐次还没有饮食记录')
              .fontSize(8)
              .fontColor('#748079')
              .padding({ top: 10, bottom: 10 })
          }
        }
        .width(152)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 3, bottom: 18 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 24, bottom: 12 })
    .backgroundColor('#0A0E0C')
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .onDigitalCrown((event: CrownEvent) => { this.handleCrownScroll(event); })
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 20 })
        .onActionEnd((event: GestureEvent) => {
          if (event.offsetX > 55) this.handleSwipeBack();
        })
    )
  }
}
