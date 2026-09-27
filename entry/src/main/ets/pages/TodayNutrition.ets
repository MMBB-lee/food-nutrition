import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { DailyNutritionSummary, FoodRecord } from '../model/NutritionModels';
import { LocalNutritionStore } from '../service/LocalNutritionStore';

@Entry
@Component
struct TodayNutritionPage {
  @State records: FoodRecord[] = [];
  @State todayCalories: number = 0;
  @State calorieTarget: number = 1800;
  @State showEditor: boolean = false;
  @State selectedRecordId: string = '';
  @State selectedFoodName: string = '';
  @State selectedFoodEmoji: string = '';
  @State editingWeight: number = 100;
  @State unlockedMealIndex: number = 0;
  @State nextMealIndex: number = 0;
  private pageScroller: Scroller = new Scroller();
  private progressTimer: number = -1;

  aboutToAppear(): void {
    this.loadTodayData();
    if (this.progressTimer >= 0) clearInterval(this.progressTimer);
    this.progressTimer = setInterval(() => {
      this.loadTodayData();
    }, 30000);
  }

  onPageShow(): void {
    this.loadTodayData();
  }

  aboutToDisappear(): void {
    if (this.progressTimer >= 0) {
      clearInterval(this.progressTimer);
      this.progressTimer = -1;
    }
  }

  async loadTodayData(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.records = await LocalNutritionStore.getFoodRecordsByDay(context, LocalNutritionStore.getDayKey());
      const summary: DailyNutritionSummary = LocalNutritionStore.summarize(this.records);
      this.todayCalories = summary.calories;
      this.calorieTarget = await LocalNutritionStore.getCalorieTarget(context);
      this.nextMealIndex = await LocalNutritionStore.resolveMealProgressFromSettings(context);
      this.unlockedMealIndex = Math.min(this.nextMealIndex, 2);
    } catch (error) {
      console.error(`load today nutrition failed: ${JSON.stringify(error)}`);
    }
  }

  getMealName(mealIndex: number): string {
    if (mealIndex === 0) return '早餐🌅';
    if (mealIndex === 1) return '午餐☀️';
    return '晚餐🌙';
  }

  getMealRecords(mealIndex: number): FoodRecord[] {
    return this.records.filter((record: FoodRecord) => record.mealIndex === mealIndex);
  }

  getMealCalories(mealIndex: number): number {
    let calories: number = 0;
    this.getMealRecords(mealIndex).forEach((record: FoodRecord) => { calories += record.energyKCal; });
    return calories;
  }

  openRecordEditor(record: FoodRecord): void {
    if (!this.isMealUnlocked(record.mealIndex)) return;
    this.selectedRecordId = record.id;
    this.selectedFoodName = record.foodName;
    this.selectedFoodEmoji = record.emoji;
    this.editingWeight = record.weight;
    this.showEditor = true;
  }

  changeWeight(offset: number): void {
    this.editingWeight = Math.max(1, Math.min(2000, this.editingWeight + offset));
  }

  setWeight(value: string): void {
    const parsed: number = Number(value);
    if (!Number.isNaN(parsed) && parsed > 0) {
      this.editingWeight = Math.max(1, Math.min(2000, Math.floor(parsed)));
    }
  }

  async saveWeight(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      await LocalNutritionStore.updateFoodRecordWeight(context, this.selectedRecordId, this.editingWeight);
      this.showEditor = false;
      await this.loadTodayData();
    } catch (error) {
      console.error(`update food record failed: ${JSON.stringify(error)}`);
    }
  }

  async deleteRecord(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      await LocalNutritionStore.deleteFoodRecord(context, this.selectedRecordId);
      this.showEditor = false;
      await this.loadTodayData();
    } catch (error) {
      console.error(`delete food record failed: ${JSON.stringify(error)}`);
    }
  }

  openFoodRecord(mealIndex: number): void {
    if (!this.isMealUnlocked(mealIndex)) return;
    router.pushUrl({ url: 'pages/FoodRecord', params: { mealIndex: mealIndex } });
  }

  isMealUnlocked(mealIndex: number): boolean {
    return mealIndex <= this.unlockedMealIndex;
  }

  isMealCompleted(mealIndex: number): boolean {
    return mealIndex < this.nextMealIndex;
  }

  handleSwipeBack(): void {
    if (this.showEditor) {
      this.showEditor = false;
    } else {
      router.back();
    }
  }

  handleCrownScroll(event: CrownEvent): void {
    if (event.action !== CrownAction.UPDATE || this.showEditor) return;
    this.pageScroller.scrollBy(0, -event.degree * 2.5);
    event.stopPropagation();
  }

  @Builder
  foodRecordRow(record: FoodRecord) {
    Row({ space: 5 }) {
      Text(record.emoji)
        .width(22)
        .fontSize(13)
        .textAlign(TextAlign.Center)
      Column({ space: 1 }) {
        Text(record.foodName)
          .fontSize(9)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F4F7F5')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${record.weight}g · ${record.energyKCal} kcal`)
          .fontSize(7)
          .fontColor('#8F9B95')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(15)
        .fontColor('#67D89A')
    }
    .width(172)
    .height(29)
    .padding({ left: 7, right: 9 })
    .backgroundColor('#18211E')
    .borderRadius(15)
    .onClick(() => { this.openRecordEditor(record); })
  }

  @Builder
  mealSection(mealIndex: number) {
    Column({ space: 3 }) {
      Row() {
        Text(this.getMealName(mealIndex))
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F4F7F5')
          .layoutWeight(1)
        if (this.isMealCompleted(mealIndex)) {
          Text('✓ 已完成')
            .fontSize(7)
            .fontColor('#67D89A')
            .margin({ right: 5 })
        }
        Text(`${this.getMealCalories(mealIndex)} kcal`)
          .fontSize(8)
          .fontColor('#F5C96A')
        Button('+')
          .width(23)
          .height(20)
          .fontSize(11)
          .fontColor(this.isMealUnlocked(mealIndex) ? '#092117' : '#69736E')
          .backgroundColor(this.isMealUnlocked(mealIndex) ? '#67D89A' : '#252F2B')
          .borderRadius(10)
          .padding(0)
          .margin({ left: 5 })
          .enabled(this.isMealUnlocked(mealIndex))
          .onClick(() => { this.openFoodRecord(mealIndex); })
      }
      .width(168)

      if (!this.isMealUnlocked(mealIndex)) {
        Text(mealIndex === 1 ? '确认吃完早餐🌅后解锁' : '确认吃完午餐☀️后解锁')
          .width(172)
          .height(25)
          .fontSize(9)
          .fontColor('#6F7B75')
          .textAlign(TextAlign.Center)
          .backgroundColor('#101613')
          .borderRadius(13)
      } else if (this.getMealRecords(mealIndex).length === 0) {
        Text('暂无记录')
          .width(172)
          .height(25)
          .fontSize(8)
          .fontColor('#6F7B75')
          .textAlign(TextAlign.Center)
          .backgroundColor('#121916')
          .borderRadius(13)
      } else {
        ForEach(this.getMealRecords(mealIndex), (record: FoodRecord) => {
          this.foodRecordRow(record)
        }, (record: FoodRecord) =>
          `${record.id}-${record.weight}-${record.energyKCal}-${record.protein}-${record.fat}-${record.carbohydrate}`)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  editorPanel() {
    Column({ space: 7 }) {
      Text(`${this.selectedFoodEmoji} ${this.selectedFoodName}`)
        .width(160)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)
        .maxLines(2)

      Row({ space: 6 }) {
        Button('-')
          .width(30).height(27).fontSize(13).backgroundColor('#28332F').borderRadius(14).padding(0)
          .onClick(() => { this.changeWeight(-10); })
        TextInput({ text: `${this.editingWeight}` })
          .width(54).height(27).type(InputType.Number).fontSize(10).fontColor('#F7FAF8')
          .textAlign(TextAlign.Center).backgroundColor('#18211E').borderRadius(14).padding(0)
          .onChange((value: string) => { this.setWeight(value); })
        Text('g').fontSize(9).fontColor('#8F9B95')
        Button('+')
          .width(30).height(27).fontSize(13).backgroundColor('#28332F').borderRadius(14).padding(0)
          .onClick(() => { this.changeWeight(10); })
      }

      Row({ space: 5 }) {
        Button('删除')
          .width(48).height(24).fontSize(8).fontColor('#F2A2A2')
          .backgroundColor('#3A2525').borderRadius(12)
          .onClick(() => { this.deleteRecord(); })
        Button('取消')
          .width(48).height(24).fontSize(8).backgroundColor('#28332F').borderRadius(12)
          .onClick(() => { this.showEditor = false; })
        Button('保存')
          .width(54).height(24).fontSize(8).fontColor('#092117')
          .backgroundColor('#67D89A').borderRadius(12)
          .onClick(() => { this.saveWeight(); })
      }
    }
    .width(184)
    .padding({ top: 13, right: 9, bottom: 12, left: 9 })
    .backgroundColor('#F2131A18')
    .border({ width: 1, color: '#34403B' })
    .borderRadius(25)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 3 }) {
        Text('今日营养')
          .width(176)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FAF8')
          .textAlign(TextAlign.Center)

        Row() {
          Column({ space: 0 }) {
            Text('今日摄入').fontSize(7).fontColor('#8F9B95')
            Text(`${this.todayCalories} kcal`).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#67D89A')
          }.width(82)
          Column({ space: 0 }) {
            Text('每日目标').fontSize(7).fontColor('#8F9B95')
            Text(`${this.calorieTarget} kcal`).fontSize(10).fontColor('#F5C96A')
          }.width(82)
        }
        .width(172)
        .height(36)
        .justifyContent(FlexAlign.SpaceAround)
        .backgroundColor('#131B18')
        .borderRadius(18)

        Scroll(this.pageScroller) {
          Column({ space: 7 }) {
            this.mealSection(0)
            this.mealSection(1)
            this.mealSection(2)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 3, bottom: 22 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 20, bottom: 14 })

      if (this.showEditor) {
        Column() {
          this.editorPanel()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#D90A0E0C')
      }
    }
    .width('100%')
    .height('100%')
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
