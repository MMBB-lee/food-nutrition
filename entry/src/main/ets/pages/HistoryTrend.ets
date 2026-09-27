import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { NutritionHistoryDay } from '../model/NutritionModels';
import { LocalNutritionStore } from '../service/LocalNutritionStore';

@Entry
@Component
struct HistoryTrendPage {
  @State history: NutritionHistoryDay[] = [];
  @State selectedRange: number = 7;
  private pageScroller: Scroller = new Scroller();
  private calorieChartScroller: Scroller = new Scroller();
  private carbohydrateChartScroller: Scroller = new Scroller();
  private fatChartScroller: Scroller = new Scroller();
  private proteinChartScroller: Scroller = new Scroller();
  private readonly chartHeight: number = 72;

  aboutToAppear(): void {
    this.loadHistory();
  }

  onPageShow(): void {
    this.loadHistory();
  }

  async loadHistory(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.history = await LocalNutritionStore.getNutritionHistory(context, this.selectedRange);
      if (this.selectedRange === 30) {
        setTimeout(() => {
          this.calorieChartScroller.scrollEdge(Edge.End);
          this.carbohydrateChartScroller.scrollEdge(Edge.End);
          this.fatChartScroller.scrollEdge(Edge.End);
          this.proteinChartScroller.scrollEdge(Edge.End);
        }, 50);
      }
    } catch (error) {
      console.error(`load nutrition history failed: ${JSON.stringify(error)}`);
    }
  }

  getMetricValue(day: NutritionHistoryDay, metric: string): number {
    if (metric === 'carbohydrate') return day.carbohydrate;
    if (metric === 'fat') return day.fat;
    if (metric === 'protein') return day.protein;
    return day.calories;
  }

  getMetricTarget(day: NutritionHistoryDay, metric: string): number {
    if (metric === 'carbohydrate') return day.carbohydrateTarget;
    if (metric === 'fat') return day.fatTarget;
    if (metric === 'protein') return day.proteinTarget;
    return day.calorieTarget;
  }

  getMetricColor(metric: string): string {
    if (metric === 'carbohydrate') return '#5BC0EB';
    if (metric === 'fat') return '#F5C96A';
    if (metric === 'protein') return '#B58AE8';
    return '#67D89A';
  }

  getMetricUnit(metric: string): string {
    return metric === 'calories' ? 'kcal' : 'g';
  }

  getAverageValue(metric: string): number {
    if (this.history.length === 0) return 0;
    let total: number = 0;
    this.history.forEach((day: NutritionHistoryDay) => {
      total += this.getMetricValue(day, metric);
    });
    return total / this.history.length;
  }

  getAverageTarget(metric: string): number {
    if (this.history.length === 0) return 0;
    let total: number = 0;
    this.history.forEach((day: NutritionHistoryDay) => {
      total += this.getMetricTarget(day, metric);
    });
    return total / this.history.length;
  }

  getAchievedDays(metric: string): number {
    let achievedDays: number = 0;
    this.history.forEach((day: NutritionHistoryDay) => {
      if (this.getMetricValue(day, metric) >= this.getMetricTarget(day, metric)) {
        achievedDays++;
      }
    });
    return achievedDays;
  }

  formatMetricValue(value: number, metric: string): string {
    if (metric === 'calories') return `${Math.round(value)}`;
    return `${Math.round(value * 10) / 10}`;
  }

  getComparisonText(metric: string): string {
    const difference: number = this.getAverageValue(metric) - this.getAverageTarget(metric);
    if (Math.abs(difference) < 0.05) return '与目标相比：平均持平';
    const direction: string = difference > 0 ? '多' : '少';
    return `与目标相比：平均${direction}${this.formatMetricValue(Math.abs(difference), metric)} ${this.getMetricUnit(metric)}`;
  }

  getChartStep(metric: string): number {
    if (metric === 'calories') return 500;
    if (metric === 'carbohydrate') return 50;
    return 20;
  }

  getChartMax(metric: string): number {
    let maximum: number = 0;
    this.history.forEach((day: NutritionHistoryDay) => {
      maximum = Math.max(maximum, this.getMetricValue(day, metric), this.getMetricTarget(day, metric));
    });
    const step: number = this.getChartStep(metric);
    return Math.max(step, Math.ceil(maximum / step) * step);
  }

  getBarWidth(): number {
    return 12;
  }

  getBarSpace(): number {
    return 8;
  }

  getBarHeight(day: NutritionHistoryDay, metric: string): number {
    const value: number = this.getMetricValue(day, metric);
    if (value <= 0) return 2;
    return Math.max(3, Math.min(this.chartHeight, this.chartHeight * value / this.getChartMax(metric)));
  }

  getTargetMarkerY(day: NutritionHistoryDay, metric: string): number {
    const markerHeight: number = this.chartHeight * this.getMetricTarget(day, metric) / this.getChartMax(metric);
    return Math.max(0, this.chartHeight - markerHeight);
  }

  getDayLabel(dayKey: string): string {
    const parts: string[] = dayKey.split('-');
    if (parts.length < 3) return '';
    return `${parts[1]}/${parts[2]}`;
  }

  getWeekday(dayKey: string): string {
    const parts: string[] = dayKey.split('-');
    if (parts.length < 3) return '';
    const date: Date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    const labels: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    return labels[date.getDay()];
  }

  getRangeCaption(): string {
    if (this.history.length === 0) return '';
    return `${this.getDayLabel(this.history[0].dayKey)} — ${this.getDayLabel(this.history[this.history.length - 1].dayKey)}`;
  }

  openDay(day: NutritionHistoryDay): void {
    router.pushUrl({ url: 'pages/NutritionDetail', params: { dayKey: day.dayKey } });
  }

  handleCrownScroll(event: CrownEvent): void {
    if (event.action !== CrownAction.UPDATE) return;
    this.pageScroller.scrollBy(0, -event.degree * 2.5);
    event.stopPropagation();
  }

  @Builder
  rangeButton(days: number) {
    Button(days === 7 ? '近7天' : '近30天')
      .width(56)
      .height(24)
      .fontSize(9)
      .fontColor(this.selectedRange === days ? '#092117' : '#C9D2CD')
      .backgroundColor(this.selectedRange === days ? '#67D89A' : '#202A26')
      .borderRadius(12)
      .padding(0)
      .onClick(() => {
        this.selectedRange = days;
        this.loadHistory();
      })
  }

  @Builder
  historyBar(day: NutritionHistoryDay, metric: string) {
    Stack() {
      Column() {
        Blank().height(this.chartHeight - this.getBarHeight(day, metric))
        Column()
          .width(this.getBarWidth())
          .height(this.getBarHeight(day, metric))
          .backgroundColor(this.getMetricColor(metric))
          .borderRadius(3)
      }
      .width('100%')
      .height(this.chartHeight)
      .alignItems(HorizontalAlign.Center)

      Row()
        .width(this.getBarWidth() + 2)
        .height(2)
        .backgroundColor('#F5C96A')
        .position({ x: -1, y: this.getTargetMarkerY(day, metric) })
    }
    .width(this.getBarWidth())
    .height(this.chartHeight)
    .onClick(() => {
      this.openDay(day);
    })
  }

  @Builder
  trendChart(metric: string, targetTitle: string, chartScroller: Scroller, showDivider: boolean) {
    Column({ space: 3 }) {
      Text(targetTitle)
        .fontSize(9)
        .fontWeight(FontWeight.Medium)
        .fontColor('#F5C96A')

      if (this.selectedRange === 30) {
        Row({ space: 3 }) {
          Column() {
            Text(`${this.getChartMax(metric)}`).fontSize(7).fontColor('#8F9B95')
            Blank().layoutWeight(1)
            Text('0').fontSize(7).fontColor('#8F9B95')
          }
          .width(22)
          .height(this.chartHeight)
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(HorizontalAlign.End)

          Scroll(chartScroller) {
            Row() {
              ForEach(this.history, (day: NutritionHistoryDay) => {
                Column({ space: 2 }) {
                  this.historyBar(day, metric)
                  Text(this.getDayLabel(day.dayKey))
                    .width(20)
                    .fontSize(6)
                    .fontColor('#8F9B95')
                    .textAlign(TextAlign.Center)
                }
                .width(20)
                .alignItems(HorizontalAlign.Center)
              }, (day: NutritionHistoryDay) => `${metric}-${day.dayKey}`)
            }
            .height(this.chartHeight + 12)
            .alignItems(VerticalAlign.Bottom)
          }
          .width(150)
          .height(this.chartHeight + 12)
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.None)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .justifyContent(FlexAlign.Center)
      } else {
        Row({ space: 3 }) {
          Column() {
            Text(`${this.getChartMax(metric)}`).fontSize(7).fontColor('#8F9B95')
            Blank().layoutWeight(1)
            Text('0').fontSize(7).fontColor('#8F9B95')
          }
          .width(22)
          .height(this.chartHeight)
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(HorizontalAlign.End)

          Row({ space: this.getBarSpace() }) {
            ForEach(this.history, (day: NutritionHistoryDay) => {
              this.historyBar(day, metric)
            }, (day: NutritionHistoryDay) => `${metric}-${day.dayKey}`)
          }
          .width(150)
          .height(this.chartHeight)
          .alignItems(VerticalAlign.Bottom)
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Row() {
          ForEach(this.history, (day: NutritionHistoryDay) => {
            Text(this.getWeekday(day.dayKey))
              .width(20)
              .fontSize(7)
              .fontColor('#8F9B95')
              .textAlign(TextAlign.Center)
          }, (day: NutritionHistoryDay) => `${metric}-label-${day.dayKey}`)
        }
        .width(150)
        .justifyContent(FlexAlign.SpaceBetween)
      }

      Column({ space: 2 }) {
        Text(`${this.selectedRange}日平均：${this.formatMetricValue(this.getAverageValue(metric), metric)} ${this.getMetricUnit(metric)}`)
          .fontSize(8)
          .fontColor('#F7FAF8')
        Text(`达标天数：${this.getAchievedDays(metric)} / ${this.history.length}天`)
          .fontSize(8)
          .fontColor('#F7FAF8')
        Text(this.getComparisonText(metric))
          .fontSize(8)
          .fontColor('#F7FAF8')
      }
      .width(150)
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 7 })

      if (showDivider) {
        Divider()
          .width(174)
          .strokeWidth(1)
          .color('#FFFFFF')
          .opacity(0.45)
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ bottom: 16 })
  }

  build() {
    Scroll(this.pageScroller) {
      Column({ space: 7 }) {
        Row() {
          Text('❮')
            .width(30)
            .height(28)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FAF8')
            .textAlign(TextAlign.Center)
            .onClick(() => { router.back(); })
          Text('历史趋势')
            .layoutWeight(1)
            .height(25)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FAF8')
            .textAlign(TextAlign.Center)
          Blank().width(30).height(28)
        }
        .width(176)
        .height(28)

        Row({ space: 8 }) {
          this.rangeButton(7)
          this.rangeButton(30)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Text(`每日摄入 · ${this.getRangeCaption()}`)
          .fontSize(9)
          .fontColor('#C9D2CD')

        this.trendChart('calories', '目标热量', this.calorieChartScroller, true)
        this.trendChart('carbohydrate', '目标碳水', this.carbohydrateChartScroller, true)
        this.trendChart('fat', '目标脂肪', this.fatChartScroller, true)
        this.trendChart('protein', '目标蛋白质', this.proteinChartScroller, false)

        Text('点击柱状图查看当天营养详情')
          .fontSize(8)
          .fontColor('#AAB4AF')
          .margin({ top: 4, bottom: 18 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 22, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.None)
    .backgroundColor('#0A0E0C')
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .onDigitalCrown((event: CrownEvent) => { this.handleCrownScroll(event); })
  }
}
