import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { FoodItem, FoodRecord } from '../model/NutritionModels';
import { FoodRecordStore } from '../service/FoodRecordStore';
import { NutritionDateUtils } from '../service/NutritionDateUtils';

interface FoodRecordParams {
  mealIndex: number;
}

@Entry
@Component
struct FoodRecordPage {
  @State foodItems: FoodItem[] = [];
  @State foodDataLoaded: boolean = false;
  @State foodDataError: boolean = false;
  @State searchText: string = '';
  @State searchInputActive: boolean = false;
  @State selectedFoodIndex: number = -1;
  @State foodWeight: number = 100;
  @State mealIndex: number = 0;
  @State showDetail: boolean = false;
  @State showWeight: boolean = false;
  @State statusText: string = '';
  @State showStatus: boolean = false;
  @State mealRecordCounts: number[] = [0, 0, 0];
  @State mealCalories: number[] = [0, 0, 0];
  private statusTimer: number = -1;
  private searchScroller: Scroller = new Scroller();
  private detailScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const params: FoodRecordParams = router.getParams() as FoodRecordParams;
    if (params !== undefined && params.mealIndex >= 0 && params.mealIndex <= 2) {
      this.mealIndex = params.mealIndex;
    }
    this.loadFoodDatabase();
    this.loadTodayMealStats();
  }

  aboutToDisappear(): void {
    if (this.statusTimer >= 0) {
      clearTimeout(this.statusTimer);
      this.statusTimer = -1;
    }
  }

  getMealName(index: number): string {
    if (index === 0) return '早餐🌅';
    if (index === 1) return '午餐☀️';
    return '晚餐🌙';
  }

  handleSwipeBack(): void {
    if (this.showWeight) {
      this.showWeight = false;
      this.showDetail = true;
    } else if (this.showDetail) {
      this.showDetail = false;
    } else {
      router.back();
    }
  }

  handleCrownScroll(event: CrownEvent): void {
    if (event.action !== CrownAction.UPDATE) return;
    const scrollDistance: number = -event.degree * 2.5;
    if (this.showDetail) {
      this.detailScroller.scrollBy(0, scrollDistance);
    } else if (!this.showWeight) {
      this.searchScroller.scrollBy(0, scrollDistance);
    }
    event.stopPropagation();
  }

  getTopCategory(category: string): string {
    const separatorIndex: number = category.indexOf('-');
    return separatorIndex >= 0 ? category.substring(0, separatorIndex) : category;
  }

  getCategoryEmoji(topCategory: string): string {
    if (topCategory === '乳类及其制品') return '🥛';
    if (topCategory === '坚果种子类') return '🥜';
    if (topCategory === '干豆类及其制品') return '🫘';
    if (topCategory === '植物油') return '🫒';
    if (topCategory === '水果类及其制品') return '🍎';
    if (topCategory === '畜肉类及其制品') return '🥩';
    if (topCategory === '禽肉类及其制品') return '🍗';
    if (topCategory === '菌藻类') return '🍄';
    if (topCategory === '蔬菜类及其制品') return '🥬';
    if (topCategory === '薯类淀粉及其制品') return '🍠';
    if (topCategory === '蛋类及其制品') return '🥚';
    if (topCategory === '谷类及其制品') return '🌾';
    if (topCategory === '鱼虾蟹贝类') return '🐟';
    return '🍽️';
  }

  parseCsvRow(line: string): string[] {
    const values: string[] = [];
    let current: string = '';
    let quoted: boolean = false;
    for (let index: number = 0; index < line.length; index++) {
      const character: string = line.charAt(index);
      if (character === '"') {
        if (quoted && index + 1 < line.length && line.charAt(index + 1) === '"') {
          current += '"';
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (character === ',' && !quoted) {
        values.push(current);
        current = '';
      } else {
        current += character;
      }
    }
    values.push(current);
    return values;
  }

  parseFoodNumber(value: string): number {
    const parsed: number = Number(value.trim());
    return Number.isNaN(parsed) ? 0 : parsed;
  }

  async loadFoodDatabase(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const content: Uint8Array = await context.resourceManager.getRawFileContent('food_composition.csv');
      const csvText: string = new util.TextDecoder().decodeToString(content).replace(/\r/g, '');
      const lines: string[] = csvText.split('\n');
      const loadedFoods: FoodItem[] = [];
      for (let index: number = 1; index < lines.length; index++) {
        if (lines[index].trim().length === 0) continue;
        const row: string[] = this.parseCsvRow(lines[index]);
        if (row.length < 35 || row[2].trim().length === 0) continue;
        const category: string = row[0].trim();
        const topCategory: string = this.getTopCategory(category);
        loadedFoods.push({
          id: index,
          foodCode: row[1].trim(),
          name: row[2].trim(),
          category: category,
          topCategory: topCategory,
          emoji: this.getCategoryEmoji(topCategory),
          edible: this.parseFoodNumber(row[4]),
          energyKCal: this.parseFoodNumber(row[6]),
          protein: this.parseFoodNumber(row[8]),
          fat: this.parseFoodNumber(row[9]),
          carbohydrate: this.parseFoodNumber(row[10]),
          dietaryFiber: this.parseFoodNumber(row[11]),
          cholesterol: this.parseFoodNumber(row[12]),
          vitaminA: this.parseFoodNumber(row[14]),
          thiamin: this.parseFoodNumber(row[17]),
          riboflavin: this.parseFoodNumber(row[18]),
          niacin: this.parseFoodNumber(row[19]),
          vitaminC: this.parseFoodNumber(row[20]),
          vitaminETotal: this.parseFoodNumber(row[21]),
          calcium: this.parseFoodNumber(row[25]),
          phosphorus: this.parseFoodNumber(row[26]),
          potassium: this.parseFoodNumber(row[27]),
          sodium: this.parseFoodNumber(row[28]),
          magnesium: this.parseFoodNumber(row[29]),
          iron: this.parseFoodNumber(row[30]),
          zinc: this.parseFoodNumber(row[31]),
          selenium: this.parseFoodNumber(row[32]),
          copper: this.parseFoodNumber(row[33]),
          manganese: this.parseFoodNumber(row[34])
        });
      }
      this.foodItems = loadedFoods;
      this.foodDataError = false;
    } catch (error) {
      console.error(`load food database failed: ${JSON.stringify(error)}`);
      this.foodDataError = true;
    }
    this.foodDataLoaded = true;
  }

  getCommonFoods(): FoodItem[] {
    const commonNames: string[] = [
      '米饭（蒸，代表值）', '鸡蛋（代表值）', '鸡胸脯肉', '苹果（代表值）', '纯牛奶（代表值，全脂）'
    ];
    const result: FoodItem[] = [];
    commonNames.forEach((name: string) => {
      const food: FoodItem | undefined = this.foodItems.find((item: FoodItem) => item.name === name);
      if (food !== undefined) result.push(food);
    });
    return result;
  }

  getFilteredFoods(): FoodItem[] {
    const keyword: string = this.searchText.trim();
    return keyword.length === 0 ? this.getCommonFoods() :
      this.foodItems.filter((food: FoodItem) => food.name.includes(keyword));
  }

  getSelectedFood(): FoodItem {
    if (this.selectedFoodIndex >= 0 && this.selectedFoodIndex < this.foodItems.length) {
      return this.foodItems[this.selectedFoodIndex];
    }
    return this.foodItems[0];
  }

  chooseFood(foodId: number): void {
    this.selectedFoodIndex = this.foodItems.findIndex((food: FoodItem) => food.id === foodId);
    if (this.selectedFoodIndex >= 0) {
      this.foodWeight = 100;
      this.showDetail = true;
    }
  }

  calculateFoodValue(valuePer100Gram: number): number {
    return Math.round(valuePer100Gram * this.foodWeight / 10) / 10;
  }

  changeFoodWeight(offset: number): void {
    this.foodWeight = Math.max(1, Math.min(2000, this.foodWeight + offset));
  }

  setFoodWeight(value: string): void {
    const parsed: number = Number(value);
    if (!Number.isNaN(parsed) && parsed > 0) {
      this.foodWeight = Math.max(1, Math.min(2000, Math.floor(parsed)));
    }
  }

  showMessage(message: string): void {
    this.statusText = message;
    this.showStatus = true;
    if (this.statusTimer >= 0) clearTimeout(this.statusTimer);
    this.statusTimer = setTimeout(() => {
      this.showStatus = false;
      this.statusTimer = -1;
    }, 1500);
  }

  async confirmFoodRecord(): Promise<void> {
    const food: FoodItem = this.getSelectedFood();
    const now: number = Date.now();
    const record: FoodRecord = {
      id: `${now}_${Math.floor(Math.random() * 100000)}`,
      recordedAt: now,
      dayKey: NutritionDateUtils.getDayKey(now),
      mealIndex: this.mealIndex,
      foodCode: food.foodCode,
      foodName: food.name,
      category: food.category,
      emoji: food.emoji,
      weight: this.foodWeight,
      energyKCal: Math.round(food.energyKCal * this.foodWeight / 100),
      protein: this.calculateFoodValue(food.protein),
      fat: this.calculateFoodValue(food.fat),
      carbohydrate: this.calculateFoodValue(food.carbohydrate),
      dietaryFiber: this.calculateFoodValue(food.dietaryFiber),
      cholesterol: this.calculateFoodValue(food.cholesterol),
      vitaminA: this.calculateFoodValue(food.vitaminA),
      thiamin: this.calculateFoodValue(food.thiamin),
      riboflavin: this.calculateFoodValue(food.riboflavin),
      niacin: this.calculateFoodValue(food.niacin),
      vitaminC: this.calculateFoodValue(food.vitaminC),
      vitaminETotal: this.calculateFoodValue(food.vitaminETotal),
      calcium: this.calculateFoodValue(food.calcium),
      phosphorus: this.calculateFoodValue(food.phosphorus),
      potassium: this.calculateFoodValue(food.potassium),
      sodium: this.calculateFoodValue(food.sodium),
      magnesium: this.calculateFoodValue(food.magnesium),
      iron: this.calculateFoodValue(food.iron),
      zinc: this.calculateFoodValue(food.zinc),
      selenium: this.calculateFoodValue(food.selenium),
      copper: this.calculateFoodValue(food.copper),
      manganese: this.calculateFoodValue(food.manganese)
    };
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      await FoodRecordStore.add(context, record);
      await this.loadTodayMealStats();
      this.showWeight = false;
      this.showDetail = false;
      this.selectedFoodIndex = -1;
      this.searchText = '';
      this.showMessage(`${food.name}已加入${this.getMealName(this.mealIndex)}，可继续添加`);
    } catch (error) {
      console.error(`save food record failed: ${JSON.stringify(error)}`);
      this.showMessage('饮食记录保存失败');
    }
  }

  async loadTodayMealStats(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const records: FoodRecord[] = await FoodRecordStore.getByDay(
        context, NutritionDateUtils.getDayKey());
      const counts: number[] = [0, 0, 0];
      const calories: number[] = [0, 0, 0];
      records.forEach((record: FoodRecord) => {
        if (record.mealIndex >= 0 && record.mealIndex <= 2) {
          counts[record.mealIndex] += 1;
          calories[record.mealIndex] += record.energyKCal;
        }
      });
      this.mealRecordCounts = counts;
      this.mealCalories = calories;
    } catch (error) {
      console.error(`load meal stats failed: ${JSON.stringify(error)}`);
    }
  }

  @Builder
  mealSelector() {
    Row({ space: 4 }) {
      ForEach([0, 1, 2], (index: number) => {
        Button(this.getMealName(index))
          .width(58)
          .height(22)
          .fontSize(9)
          .fontColor(this.mealIndex === index ? '#092117' : '#C9D2CD')
          .backgroundColor(this.mealIndex === index ? '#67D89A' : '#28332F')
          .borderRadius(11)
          .padding(0)
          .onClick(() => { this.mealIndex = index; })
      }, (index: number) => `${index}`)
    }
  }

  @Builder
  nutrientRow(label: string, value: number, unit: string) {
    Row() {
      Text(label).fontSize(7).fontColor('#AAB5AF').layoutWeight(1)
      Text(`${value} ${unit}`).fontSize(7).fontColor('#F0F4F2')
    }
    .width(150)
    .height(18)
    .padding({ left: 8, right: 8 })
    .backgroundColor('#18211E')
    .borderRadius(9)
  }

  @Builder
  searchPage() {
    Column({ space: 3 }) {
      Text(`记录饮食-${this.getMealName(this.mealIndex)}`)
        .width(176)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)

      Text(`已添加 ${this.mealRecordCounts[this.mealIndex]} 种 · ` +
        `${this.mealCalories[this.mealIndex]} kcal`)
        .fontSize(7)
        .fontColor('#8F9B95')

      if (this.searchInputActive) {
        TextInput({ placeholder: '搜索食物', text: this.searchText })
          .id('foodRecordSearchInput')
          .width(176).height(28).fontSize(12).placeholderFont({ size: 12 })
          .fontColor('#F4F7F5').placeholderColor('#748079')
          .textAlign(TextAlign.Center).backgroundColor('#18211E').borderRadius(15)
          .onChange((value: string) => { this.searchText = value; })
      } else {
        Row() {
          Text(this.searchText.length > 0 ? this.searchText : '搜索食物')
            .width('100%')
            .fontSize(12)
            .fontColor(this.searchText.length > 0 ? '#F4F7F5' : '#748079')
            .textAlign(TextAlign.Center)
        }
        .width(176).height(28).backgroundColor('#18211E').borderRadius(15)
        .onClick(() => {
          this.searchInputActive = true;
          setTimeout(() => {
            this.getUIContext().getFocusController().requestFocus('foodRecordSearchInput');
          }, 50);
        })
      }

      Text(this.searchText.trim().length === 0 ? '常见食品' : '搜索结果')
        .width(170).fontSize(8).fontColor('#C7D0CB')
        .textAlign(TextAlign.Center)

      Scroll(this.searchScroller) {
        Column({ space: 4 }) {
          if (!this.foodDataLoaded) {
            Text('正在加载食品数据').fontSize(9).fontColor('#8F9B95').margin({ top: 18 })
          } else if (this.foodDataError) {
            Text('食品数据加载失败').fontSize(9).fontColor('#E78B8B').margin({ top: 18 })
          } else if (this.getFilteredFoods().length === 0) {
            Text('未找到相关食物').fontSize(9).fontColor('#8F9B95').margin({ top: 18 })
          } else {
            ForEach(this.getFilteredFoods(), (food: FoodItem) => {
              Row({ space: 5 }) {
                Text(food.emoji).width(22).fontSize(13).textAlign(TextAlign.Center)
                Column({ space: 1 }) {
                  Text(food.name).fontSize(9).fontColor('#F4F7F5').maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${food.energyKCal} kcal/100g`).fontSize(7).fontColor('#8F9B95')
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('›').fontSize(16).fontColor('#67D89A')
              }
              .width(176).height(28).padding({ left: 8, right: 10 })
              .backgroundColor('#18211E').borderRadius(14)
              .onClick(() => { this.chooseFood(food.id); })
            }, (food: FoodItem) => `${food.id}`)
          }
        }.width('100%').alignItems(HorizontalAlign.Center)
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)

      Button('完成')
        .width(58)
        .height(21)
        .fontSize(8)
        .fontColor('#092117')
        .backgroundColor('#67D89A')
        .borderRadius(11)
        .padding(0)
        .margin({ top: 2 })
        .translate({ y: 3 })
        .onClick(() => { router.back(); })
    }
    .width('100%').height('100%').alignItems(HorizontalAlign.Center)
    .padding({ top: 18, bottom: 16 }).backgroundColor('#0A0E0C')
  }

  @Builder
  detailPage() {
    Column({ space: 5 }) {
      Text('食品详情')
        .width(166)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)
      Row({ space: 7 }) {
        Text(this.getSelectedFood().emoji).width(30).fontSize(20).textAlign(TextAlign.Center)
        Column({ space: 1 }) {
          Text(this.getSelectedFood().name).fontSize(10).fontColor('#F4F7F5').maxLines(1)
          Text(this.getSelectedFood().category).fontSize(7).fontColor('#67D89A').maxLines(2)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width(166).padding(7).backgroundColor('#131B18').borderRadius(14)
      Text('每100克可食部分的营养数据').width(150).fontSize(7).fontColor('#87938D')
      Scroll(this.detailScroller) {
        Column({ space: 2 }) {
          this.nutrientRow('可食部分', this.getSelectedFood().edible, '%')
          this.nutrientRow('能量', this.getSelectedFood().energyKCal, 'kcal')
          this.nutrientRow('蛋白质', this.getSelectedFood().protein, 'g')
          this.nutrientRow('脂肪', this.getSelectedFood().fat, 'g')
          this.nutrientRow('碳水化合物', this.getSelectedFood().carbohydrate, 'g')
          this.nutrientRow('膳食纤维', this.getSelectedFood().dietaryFiber, 'g')
          this.nutrientRow('胆固醇', this.getSelectedFood().cholesterol, 'mg')
          this.nutrientRow('维生素A', this.getSelectedFood().vitaminA, 'μg RAE')
          this.nutrientRow('维生素B1', this.getSelectedFood().thiamin, 'mg')
          this.nutrientRow('维生素B2', this.getSelectedFood().riboflavin, 'mg')
          this.nutrientRow('维生素C', this.getSelectedFood().vitaminC, 'mg')
          this.nutrientRow('维生素E', this.getSelectedFood().vitaminETotal, 'mg')
          this.nutrientRow('钙', this.getSelectedFood().calcium, 'mg')
          this.nutrientRow('磷', this.getSelectedFood().phosphorus, 'mg')
          this.nutrientRow('钾', this.getSelectedFood().potassium, 'mg')
          this.nutrientRow('钠', this.getSelectedFood().sodium, 'mg')
          this.nutrientRow('镁', this.getSelectedFood().magnesium, 'mg')
          this.nutrientRow('铁', this.getSelectedFood().iron, 'mg')
          this.nutrientRow('锌', this.getSelectedFood().zinc, 'mg')
          this.nutrientRow('硒', this.getSelectedFood().selenium, 'μg')
          this.nutrientRow('铜', this.getSelectedFood().copper, 'mg')
          this.nutrientRow('锰', this.getSelectedFood().manganese, 'mg')
        }.width('100%').alignItems(HorizontalAlign.Center)
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off).edgeEffect(EdgeEffect.None)
      Button('选择重量').width(88).height(25).fontSize(9).fontColor('#092117')
        .backgroundColor('#67D89A').borderRadius(13)
        .onClick(() => { this.showDetail = false; this.showWeight = true; })
    }
    .width('100%').height('100%').alignItems(HorizontalAlign.Center)
    .padding({ top: 24, bottom: 27 }).backgroundColor('#0A0E0C')
  }

  @Builder
  weightPage() {
    Column({ space: 6 }) {
      Text(`添加到${this.getMealName(this.mealIndex)}`).fontSize(14).fontWeight(FontWeight.Bold).fontColor('#F7FAF8')
      Text(this.getSelectedFood().name).fontSize(11).fontColor('#67D89A')
      Row({ space: 6 }) {
        Button('-').width(30).height(28).fontSize(14).backgroundColor('#28332F').borderRadius(14).padding(0)
          .onClick(() => { this.changeFoodWeight(-10); })
        TextInput({ text: `${this.foodWeight}` }).width(54).height(28).type(InputType.Number)
          .fontSize(11).fontColor('#F7FAF8').textAlign(TextAlign.Center).backgroundColor('#18211E')
          .borderRadius(14).padding(0).onChange((value: string) => { this.setFoodWeight(value); })
        Text('g').fontSize(9).fontColor('#8F9B95')
        Button('+').width(30).height(28).fontSize(14).backgroundColor('#28332F').borderRadius(14).padding(0)
          .onClick(() => { this.changeFoodWeight(10); })
      }
      Row({ space: 5 }) {
        ForEach([50, 100, 150], (weight: number) => {
          Button(`${weight}g`).width(42).height(22).fontSize(8).backgroundColor('#28332F')
            .borderRadius(11).padding(0).onClick(() => { this.foodWeight = weight; })
        }, (weight: number) => `${weight}`)
      }
      Column({ space: 2 }) {
        Text(`${Math.round(this.getSelectedFood().energyKCal * this.foodWeight / 100)} kcal`)
          .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#F5C96A')
        Text(`蛋白质 ${this.calculateFoodValue(this.getSelectedFood().protein)}g  脂肪 ${this.calculateFoodValue(this.getSelectedFood().fat)}g`)
          .fontSize(8).fontColor('#C9D2CD')
        Text(`碳水 ${this.calculateFoodValue(this.getSelectedFood().carbohydrate)}g`).fontSize(8).fontColor('#70C9FF')
      }.width(166).padding({ top: 7, bottom: 7 }).backgroundColor('#18211E').borderRadius(16)
      Row({ space: 7 }) {
        Button('返回').width(60).height(27).fontSize(9).backgroundColor('#28332F').borderRadius(14)
          .onClick(() => { this.showWeight = false; this.showDetail = true; })
        Button('确认添加').width(76).height(27).fontSize(9).fontColor('#092117')
          .backgroundColor('#67D89A').borderRadius(14).onClick(() => { this.confirmFoodRecord(); })
      }
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center).backgroundColor('#0A0E0C')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.showWeight) {
        this.weightPage()
      } else if (this.showDetail) {
        this.detailPage()
      } else {
        this.searchPage()
      }
      if (this.showStatus) {
        Text(this.statusText).fontSize(9).fontColor('#FFFFFF')
          .padding({ top: 7, right: 12, bottom: 7, left: 12 })
          .backgroundColor('#F05D6561').borderRadius(15).zIndex(100)
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
