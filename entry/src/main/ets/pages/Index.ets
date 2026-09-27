import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { router } from '@kit.ArkUI';
import { DailyNutritionSummary, FoodRecord } from '../model/NutritionModels';
import { LocalNutritionStore } from '../service/LocalNutritionStore';

interface MealTimeSettings {
  breakfastMinutes: number;
  lunchMinutes: number;
  dinnerMinutes: number;
}

@Entry
@Component
struct Index {
  @State showQuickMenu: boolean = false;
  @State showSettings: boolean = false;
  @State showMealSettings: boolean = false;
  @State showNutritionSettings: boolean = false;
  @State showNutritionGuide: boolean = false;
  @State showPrivacyPermissions: boolean = false;
  @State showAboutApp: boolean = false;
  @State showAppVersion: boolean = false;
  @State showDataSource: boolean = false;
  @State showFeedback: boolean = false;
  @State breakfastMinutes: number = 480;
  @State lunchMinutes: number = 720;
  @State dinnerMinutes: number = 1080;
  @State nowTimestamp: number = Date.now();
  @State nextMealIndex: number = 0;
  @State nextMealTimestamp: number = 0;
  @State showMealConfirm: boolean = false;
  @State notificationEnabled: boolean = false;
  @State showNotificationToast: boolean = false;
  @State notificationToastText: string = '';
  @State showCustomTime: boolean = false;
  @State settingsLoaded: boolean = false;
  @State showPrivacyConsent: boolean = true;
  @State showInitialSetup: boolean = true;
  @State customTimeFromInitialSetup: boolean = false;
  @State editingMeal: string = 'breakfast';
  @State customHour: number = 8;
  @State customMinute: number = 0;
  @State customTimeField: string = 'hour';
  @State hourWheelOffset: number = 0;
  @State minuteWheelOffset: number = 0;
  @State allMealsCompleted: boolean = false;
  @State completionDayKey: string = '';
  @State todayCalories: number = 0;
  @State todayProtein: number = 0;
  @State todayFat: number = 0;
  @State todayCarbohydrate: number = 0;
  @State dailyCalorieTarget: number = 1800;
  @State dailyCarbohydrateTarget: number = 250;
  @State dailyProteinTarget: number = 60;
  @State dailyFatTarget: number = 60;
  @State editingCalorieTarget: number = 1800;
  @State calorieTargetInput: string = '1800';
  @State editingCarbohydrateTarget: number = 250;
  @State carbohydrateTargetInput: string = '250';
  @State editingProteinTarget: number = 60;
  @State proteinTargetInput: string = '60';
  @State editingFatTarget: number = 60;
  @State fatTargetInput: string = '60';
  @State dashboardNutrientIndex: number = 0;
  private clockTimer: number = -1;
  private dashboardDayKey: string = '';
  private mealTimeSavePending: boolean = false;
  private notificationToastTimer: number = -1;
  private mealReminderIds: number[] = [];
  private settingsPreferences: preferences.Preferences | undefined = undefined;
  private pageScroller: Scroller = new Scroller();
  private crownDegreeRemainder: number = 0;
  private crownActiveTimeField: string = '';
  private wheelGestureField: string = '';
  private wheelLastPanOffset: number = 0;
  private wheelInertiaTimer: number = -1;
  private wheelInertiaVelocity: number = 0;

  aboutToAppear(): void {
    this.loadMealSettings();
    this.loadDashboardData();
    this.clockTimer = setInterval(() => {
      this.nowTimestamp = Date.now();
      this.resetDailyCompletionIfNeeded();
      if (this.dashboardDayKey !== LocalNutritionStore.getDayKey(this.nowTimestamp)) {
        this.loadDashboardData();
      }
    }, 30000);
  }

  onPageShow(): void {
    this.loadDashboardData();
  }

  handleSwipeBack(): void {
    if (this.showPrivacyConsent) {
      this.rejectPrivacyConsent();
    } else if (this.showMealConfirm) {
      this.showMealConfirm = false;
    } else if (this.showQuickMenu) {
      this.showQuickMenu = false;
    } else if (this.showAppVersion) {
      this.showAppVersion = false;
      this.showAboutApp = true;
    } else if (this.showDataSource) {
      this.showDataSource = false;
      this.showAboutApp = true;
    } else if (this.showAboutApp) {
      this.showAboutApp = false;
      this.showSettings = true;
    } else if (this.showFeedback) {
      this.showFeedback = false;
      this.showSettings = true;
    } else if (this.showPrivacyPermissions) {
      this.showPrivacyPermissions = false;
      this.showSettings = true;
    } else if (this.showNutritionGuide) {
      this.showNutritionGuide = false;
      this.showNutritionSettings = true;
    } else if (this.showCustomTime) {
      this.showCustomTime = false;
      if (!this.customTimeFromInitialSetup) this.showMealSettings = true;
      this.customTimeFromInitialSetup = false;
    } else if (this.showNutritionSettings) {
      this.showNutritionSettings = false;
      this.showSettings = true;
    } else if (this.showMealSettings) {
      this.showMealSettings = false;
      this.showSettings = true;
    } else if (this.showSettings) {
      this.showSettings = false;
    }
  }

  handleCrownScroll(event: CrownEvent): void {
    if (event.action !== CrownAction.UPDATE) return;
    if (this.showCustomTime) {
      if (this.crownActiveTimeField !== this.customTimeField) {
        this.crownActiveTimeField = this.customTimeField;
        this.crownDegreeRemainder = 0;
      }
      this.crownDegreeRemainder += event.degree;
      const valueCount: number = this.customTimeField === 'hour' ? 24 : 60;
      const degreesPerStep: number = 24;
      const steps: number = Math.trunc(this.crownDegreeRemainder / degreesPerStep);
      if (steps !== 0) {
        this.setDialValue((this.getCurrentDialValue() + steps + valueCount) % valueCount);
        this.crownDegreeRemainder -= steps * degreesPerStep;
      }
      event.stopPropagation();
      return;
    }
    this.pageScroller.scrollBy(0, -event.degree * 2.5);
    event.stopPropagation();
  }

  async loadDashboardData(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      await LocalNutritionStore.getFirstUseDayKey(context);
      const dayKey: string = LocalNutritionStore.getDayKey();
      const records: FoodRecord[] = await LocalNutritionStore.getFoodRecordsByDay(
        context, dayKey);
      const summary: DailyNutritionSummary = LocalNutritionStore.summarize(records);
      const calorieTarget: number = await LocalNutritionStore.getCalorieTarget(context);
      const carbohydrateTarget: number = await LocalNutritionStore.getCarbohydrateTarget(context);
      const proteinTarget: number = await LocalNutritionStore.getProteinTarget(context);
      const fatTarget: number = await LocalNutritionStore.getFatTarget(context);
      if (dayKey !== LocalNutritionStore.getDayKey()) {
        await this.loadDashboardData();
        return;
      }
      this.dashboardDayKey = dayKey;
      this.todayCalories = summary.calories;
      this.todayProtein = summary.protein;
      this.todayFat = summary.fat;
      this.todayCarbohydrate = summary.carbohydrate;
      this.dailyCalorieTarget = calorieTarget;
      this.dailyCarbohydrateTarget = carbohydrateTarget;
      this.dailyProteinTarget = proteinTarget;
      this.dailyFatTarget = fatTarget;
      this.editingCalorieTarget = this.dailyCalorieTarget;
      this.calorieTargetInput = `${this.dailyCalorieTarget}`;
      this.editingCarbohydrateTarget = this.dailyCarbohydrateTarget;
      this.carbohydrateTargetInput = `${this.dailyCarbohydrateTarget}`;
      this.editingProteinTarget = this.dailyProteinTarget;
      this.proteinTargetInput = `${this.dailyProteinTarget}`;
      this.editingFatTarget = this.dailyFatTarget;
      this.fatTargetInput = `${this.dailyFatTarget}`;
    } catch (error) {
      console.error(`load dashboard data failed: ${JSON.stringify(error)}`);
    }
  }

  async loadMealSettings(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.settingsPreferences = await preferences.getPreferences(context, { name: 'meal_settings' });
      const setupComplete: boolean = await this.settingsPreferences.get('setupComplete', false) as boolean;
      const privacyAccepted: boolean =
        await this.settingsPreferences.get('privacyAccepted', false) as boolean;
      const savedBreakfast: number = await this.settingsPreferences.get('breakfastMinutes', 480) as number;
      const savedLunch: number = await this.settingsPreferences.get('lunchMinutes', 720) as number;
      const savedDinner: number = await this.settingsPreferences.get('dinnerMinutes', 1080) as number;
      const savedNotificationEnabled: boolean =
        await this.settingsPreferences.get('notificationEnabled', false) as boolean;

      if (savedBreakfast < savedLunch && savedLunch < savedDinner) {
        this.breakfastMinutes = savedBreakfast;
        this.lunchMinutes = savedLunch;
        this.dinnerMinutes = savedDinner;
      }
      this.showInitialSetup = !setupComplete;
      this.showPrivacyConsent = !privacyAccepted;
      this.notificationEnabled = savedNotificationEnabled;
    } catch (error) {
      console.error(`load meal settings failed: ${JSON.stringify(error)}`);
      this.showPrivacyConsent = true;
      this.showInitialSetup = true;
    }
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      if (!this.showInitialSetup) {
        const resolvedIndex: number = await LocalNutritionStore.resolveMealProgress(
          context, this.breakfastMinutes, this.lunchMinutes, this.dinnerMinutes);
        this.applyMealProgress(resolvedIndex);
      } else {
        this.initializeNextMeal();
      }
    } catch (error) {
      console.error(`load meal progress failed: ${JSON.stringify(error)}`);
    }
    if (this.notificationEnabled && !this.showPrivacyConsent) {
      await this.restoreNotificationSetting();
    }
    this.settingsLoaded = true;
  }

  async acceptPrivacyConsent(): Promise<void> {
    if (this.settingsPreferences === undefined) return;
    try {
      await this.settingsPreferences.put('privacyAccepted', true);
      await this.settingsPreferences.flush();
      this.showPrivacyConsent = false;
    } catch (error) {
      console.error(`save privacy consent failed: ${JSON.stringify(error)}`);
      this.showNotificationStatus('隐私设置保存失败');
    }
  }

  async rejectPrivacyConsent(): Promise<void> {
    try {
      const context: common.UIAbilityContext =
        this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.terminateSelf();
    } catch (error) {
      console.error(`terminate after privacy rejection failed: ${JSON.stringify(error)}`);
    }
  }

  async persistMealSettings(markSetupComplete: boolean = false, times?: MealTimeSettings): Promise<boolean> {
    if (this.settingsPreferences === undefined) {
      return false;
    }
    try {
      await this.settingsPreferences.put('breakfastMinutes',
        times === undefined ? this.breakfastMinutes : times.breakfastMinutes);
      await this.settingsPreferences.put('lunchMinutes',
        times === undefined ? this.lunchMinutes : times.lunchMinutes);
      await this.settingsPreferences.put('dinnerMinutes',
        times === undefined ? this.dinnerMinutes : times.dinnerMinutes);
      if (markSetupComplete) {
        await this.settingsPreferences.put('setupComplete', true);
      }
      await this.settingsPreferences.flush();
      return true;
    } catch (error) {
      console.error(`save meal settings failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  async persistNotificationSetting(enabled: boolean): Promise<boolean> {
    if (this.settingsPreferences === undefined) {
      return false;
    }
    try {
      await this.settingsPreferences.put('notificationEnabled', enabled);
      await this.settingsPreferences.flush();
      return true;
    } catch (error) {
      console.error(`save notification setting failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  async restoreNotificationSetting(): Promise<void> {
    try {
      const systemEnabled: boolean = await notificationManager.isNotificationEnabled();
      if (!systemEnabled) {
        this.notificationEnabled = false;
        await this.persistNotificationSetting(false);
        return;
      }
      await this.scheduleMealNotifications();
    } catch (error) {
      console.error(`restore notification setting failed: ${JSON.stringify(error)}`);
      this.notificationEnabled = false;
      await this.persistNotificationSetting(false);
    }
  }

  async completeInitialSetup(): Promise<void> {
    const saved: boolean = await this.persistMealSettings(true);
    if (!saved) {
      this.showNotificationStatus('设置保存失败');
      return;
    }
    this.showInitialSetup = false;
    await this.syncMealProgressWithTime();
  }

  openFoodRecord(): void {
    this.showMealConfirm = false;
    router.pushUrl({
      url: 'pages/FoodRecord',
      params: { mealIndex: this.nextMealIndex }
    });
  }

  aboutToDisappear(): void {
    if (this.clockTimer >= 0) {
      clearInterval(this.clockTimer);
    }
    if (this.notificationToastTimer >= 0) {
      clearTimeout(this.notificationToastTimer);
      this.notificationToastTimer = -1;
    }
  }

  formatTime(totalMinutes: number): string {
    const normalized: number = (totalMinutes + 1440) % 1440;
    const hour: number = Math.floor(normalized / 60);
    const minute: number = normalized % 60;
    const hourText: string = hour < 10 ? `0${hour}` : `${hour}`;
    const minuteText: string = minute < 10 ? `0${minute}` : `${minute}`;
    return `${hourText}:${minuteText}`;
  }

  getDayKey(timestamp: number): string {
    const date: Date = new Date(timestamp);
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }

  resetDailyCompletionIfNeeded(): void {
    this.syncMealProgressWithTime();
  }

  applyMealProgress(nextMealIndex: number): void {
    const today: string = this.getDayKey(Date.now());
    if (nextMealIndex >= 3) {
      this.allMealsCompleted = true;
      this.completionDayKey = today;
      this.nextMealIndex = 2;
      this.nextMealTimestamp = this.createMealTimestamp(this.dinnerMinutes, false);
      this.showMealConfirm = false;
      return;
    }
    this.allMealsCompleted = false;
    this.completionDayKey = today;
    this.nextMealIndex = Math.max(0, nextMealIndex);
    this.nextMealTimestamp = this.createMealTimestamp(this.getMealMinutes(this.nextMealIndex), false);
    this.nowTimestamp = Date.now();
  }

  async syncMealProgressWithTime(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const resolvedIndex: number = await LocalNutritionStore.resolveMealProgress(
        context, this.breakfastMinutes, this.lunchMinutes, this.dinnerMinutes);
      const currentIndex: number = this.allMealsCompleted ? 3 : this.nextMealIndex;
      if (resolvedIndex !== currentIndex || this.completionDayKey !== this.getDayKey(Date.now())) {
        this.applyMealProgress(resolvedIndex);
      }
    } catch (error) {
      console.error(`sync meal progress failed: ${JSON.stringify(error)}`);
    }
  }

  async persistMealProgress(nextMealIndex: number): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      const dayKey: string = nextMealIndex < 0 ? '' : this.getDayKey(Date.now());
      await LocalNutritionStore.saveMealProgress(context, dayKey, nextMealIndex);
    } catch (error) {
      console.error(`save meal progress failed: ${JSON.stringify(error)}`);
    }
  }

  async saveNutritionSettings(): Promise<void> {
    try {
      const context: common.Context = this.getUIContext().getHostContext() as common.Context;
      this.editingCalorieTarget = this.calorieTargetInput.length > 0 ?
        Number(this.calorieTargetInput) : this.dailyCalorieTarget;
      this.editingCalorieTarget = Math.max(500, Math.min(10000, this.editingCalorieTarget));
      this.editingCarbohydrateTarget = this.normalizeNutritionTarget(this.carbohydrateTargetInput,
        this.editingCarbohydrateTarget, 1, 1000, this.dailyCarbohydrateTarget);
      this.editingProteinTarget = this.normalizeNutritionTarget(this.proteinTargetInput,
        this.editingProteinTarget, 1, 500, this.dailyProteinTarget);
      this.editingFatTarget = this.normalizeNutritionTarget(this.fatTargetInput,
        this.editingFatTarget, 1, 500, this.dailyFatTarget);
      this.calorieTargetInput = `${this.editingCalorieTarget}`;
      await LocalNutritionStore.setCalorieTarget(context, this.editingCalorieTarget);
      await LocalNutritionStore.setCarbohydrateTarget(context, this.editingCarbohydrateTarget);
      await LocalNutritionStore.setProteinTarget(context, this.editingProteinTarget);
      await LocalNutritionStore.setFatTarget(context, this.editingFatTarget);
      this.dailyCalorieTarget = this.editingCalorieTarget;
      this.dailyCarbohydrateTarget = this.editingCarbohydrateTarget;
      this.dailyProteinTarget = this.editingProteinTarget;
      this.dailyFatTarget = this.editingFatTarget;
      this.carbohydrateTargetInput = `${this.dailyCarbohydrateTarget}`;
      this.proteinTargetInput = `${this.dailyProteinTarget}`;
      this.fatTargetInput = `${this.dailyFatTarget}`;
      this.showNutritionSettings = false;
      this.showSettings = true;
      this.showNotificationStatus('营养目标已保存');
    } catch (error) {
      console.error(`save nutrition settings failed: ${JSON.stringify(error)}`);
      this.showNotificationStatus('设置保存失败');
    }
  }

  getDashboardNutrientName(): string {
    if (this.dashboardNutrientIndex === 1) return '碳水化合物';
    if (this.dashboardNutrientIndex === 2) return '蛋白质';
    if (this.dashboardNutrientIndex === 3) return '脂肪';
    return '热量';
  }

  getDashboardNutrientValue(): number {
    if (this.dashboardNutrientIndex === 1) return this.todayCarbohydrate;
    if (this.dashboardNutrientIndex === 2) return this.todayProtein;
    if (this.dashboardNutrientIndex === 3) return this.todayFat;
    return this.todayCalories;
  }

  getDashboardNutrientTarget(): number {
    if (this.dashboardNutrientIndex === 1) return this.dailyCarbohydrateTarget;
    if (this.dashboardNutrientIndex === 2) return this.dailyProteinTarget;
    if (this.dashboardNutrientIndex === 3) return this.dailyFatTarget;
    return this.dailyCalorieTarget;
  }

  getDashboardNutrientRemaining(): number {
    return Math.max(0, this.getDashboardNutrientTarget() - this.getDashboardNutrientValue());
  }

  formatDashboardNutrientValue(value: number): string {
    if (this.dashboardNutrientIndex === 0) {
      return `${Math.round(value)}`;
    }
    const rounded: number = Math.round(value * 10) / 10;
    return `${rounded}`;
  }

  getDashboardNutrientColor(): string {
    if (this.dashboardNutrientIndex === 1) return '#5BC0EB';
    if (this.dashboardNutrientIndex === 2) return '#B58AE8';
    if (this.dashboardNutrientIndex === 3) return '#F5C96A';
    return '#67D89A';
  }

  getDashboardNutrientUnit(): string {
    return this.dashboardNutrientIndex === 0 ? 'kcal' : 'g';
  }

  getNutritionTargetInput(kind: string): string {
    if (kind === 'carbohydrate') return this.carbohydrateTargetInput;
    if (kind === 'protein') return this.proteinTargetInput;
    if (kind === 'fat') return this.fatTargetInput;
    return this.calorieTargetInput;
  }

  setNutritionTargetInput(kind: string, value: string): void {
    if (kind === 'carbohydrate') {
      this.carbohydrateTargetInput = value;
      if (value.length > 0) this.editingCarbohydrateTarget = Number(value);
    } else if (kind === 'protein') {
      this.proteinTargetInput = value;
      if (value.length > 0) this.editingProteinTarget = Number(value);
    } else if (kind === 'fat') {
      this.fatTargetInput = value;
      if (value.length > 0) this.editingFatTarget = Number(value);
    } else {
      this.calorieTargetInput = value;
      if (value.length > 0) this.editingCalorieTarget = Number(value);
    }
  }

  getEditingNutritionTarget(kind: string): number {
    if (kind === 'carbohydrate') return this.editingCarbohydrateTarget;
    if (kind === 'protein') return this.editingProteinTarget;
    if (kind === 'fat') return this.editingFatTarget;
    return this.editingCalorieTarget;
  }

  setEditingNutritionTarget(kind: string, value: number): void {
    const bounded: number = this.normalizeNutritionTarget(`${value}`, value,
      kind === 'calories' ? 500 : 1, kind === 'calories' ? 10000 : (kind === 'carbohydrate' ? 1000 : 500),
      this.getEditingNutritionTarget(kind));
    this.setNutritionTargetInput(kind, `${bounded}`);
  }

  normalizeNutritionTarget(input: string, value: number, minimum: number, maximum: number,
    fallback: number): number {
    const parsed: number = input.length > 0 ? Number(input) : value;
    return Math.max(minimum, Math.min(maximum, Number.isFinite(parsed) ? Math.round(parsed) : fallback));
  }

  clampNutritionTargetInput(kind: string): void {
    let minimum: number = 1;
    let maximum: number = kind === 'carbohydrate' ? 1000 : 500;
    let fallback: number = 60;
    if (kind === 'calories') {
      minimum = 500;
      maximum = 10000;
      fallback = this.dailyCalorieTarget;
    } else if (kind === 'carbohydrate') {
      fallback = this.dailyCarbohydrateTarget;
    } else if (kind === 'protein') {
      fallback = this.dailyProteinTarget;
    } else {
      fallback = this.dailyFatTarget;
    }
    const normalized: number = this.normalizeNutritionTarget(this.getNutritionTargetInput(kind),
      this.getEditingNutritionTarget(kind), minimum, maximum, fallback);
    this.setEditingNutritionTarget(kind, normalized);
  }

  async applyMealTime(meal: string, minutes: number): Promise<boolean> {
    if (this.mealTimeSavePending) return false;
    const breakfast: number = meal === 'breakfast' ? minutes : this.breakfastMinutes;
    const lunch: number = meal === 'lunch' ? minutes : this.lunchMinutes;
    const dinner: number = meal === 'dinner' ? minutes : this.dinnerMinutes;
    if (breakfast >= lunch) {
      this.showNotificationStatus('午餐☀️时间必须晚于早餐🌅');
      return false;
    }
    if (lunch >= dinner) {
      this.showNotificationStatus('晚餐🌙时间必须晚于午餐☀️');
      return false;
    }

    this.mealTimeSavePending = true;
    let saved: boolean = false;
    try {
      saved = await this.persistMealSettings(false, {
        breakfastMinutes: breakfast,
        lunchMinutes: lunch,
        dinnerMinutes: dinner
      });
    } finally {
      this.mealTimeSavePending = false;
    }
    if (!saved) {
      this.showNotificationStatus('就餐时间保存失败');
      return false;
    }
    this.breakfastMinutes = breakfast;
    this.lunchMinutes = lunch;
    this.dinnerMinutes = dinner;
    this.syncNextMealTime();
    if (!this.showInitialSetup) {
      this.syncMealProgressWithTime();
    }
    return true;
  }

  openCustomTime(meal: string, minutes: number): void {
    this.customTimeFromInitialSetup = this.showInitialSetup;
    this.editingMeal = meal;
    this.customHour = Math.floor(minutes / 60);
    this.customMinute = minutes % 60;
    this.customTimeField = 'hour';
    this.crownActiveTimeField = 'hour';
    this.crownDegreeRemainder = 0;
    this.showMealSettings = false;
    this.showCustomTime = true;
  }

  formatTimePart(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  getCurrentDialValue(): number {
    return this.customTimeField === 'hour' ? this.customHour : this.customMinute;
  }

  setDialValue(value: number): void {
    if (this.customTimeField === 'hour') {
      this.customHour = value;
    } else {
      this.customMinute = value;
    }
  }

  selectTimeField(field: string): void {
    this.customTimeField = field;
  }

  getTimePickerRange(field: string): string[] {
    const valueCount: number = field === 'hour' ? 24 : 60;
    const values: string[] = [];
    for (let value: number = 0; value < valueCount; value++) {
      values.push(this.formatTimePart(value));
    }
    return values;
  }

  getTimePickerDisplayValue(field: string, offset: number): string {
    const valueCount: number = field === 'hour' ? 24 : 60;
    const currentValue: number = field === 'hour' ? this.customHour : this.customMinute;
    return this.formatTimePart((currentValue + offset + valueCount) % valueCount);
  }

  getTimeWheelOffset(field: string): number {
    return field === 'hour' ? this.hourWheelOffset : this.minuteWheelOffset;
  }

  setTimeWheelOffset(field: string, value: number): void {
    if (field === 'hour') {
      this.hourWheelOffset = value;
    } else {
      this.minuteWheelOffset = value;
    }
  }

  shiftTimeWheelValue(field: string, steps: number): void {
    const valueCount: number = field === 'hour' ? 24 : 60;
    const currentValue: number = field === 'hour' ? this.customHour : this.customMinute;
    const nextValue: number = (currentValue + steps + valueCount * 4) % valueCount;
    if (field === 'hour') {
      this.customHour = nextValue;
    } else {
      this.customMinute = nextValue;
    }
  }

  applyTimeWheelDelta(field: string, deltaY: number): void {
    let offset: number = this.getTimeWheelOffset(field) + deltaY;
    while (offset >= 25) {
      this.shiftTimeWheelValue(field, -1);
      offset -= 25;
    }
    while (offset <= -25) {
      this.shiftTimeWheelValue(field, 1);
      offset += 25;
    }
    this.setTimeWheelOffset(field, offset);
  }

  stopTimeWheelInertia(): void {
    if (this.wheelInertiaTimer >= 0) {
      clearInterval(this.wheelInertiaTimer);
      this.wheelInertiaTimer = -1;
    }
    this.wheelInertiaVelocity = 0;
  }

  settleTimeWheel(field: string): void {
    let offset: number = this.getTimeWheelOffset(field);
    if (offset >= 12.5) {
      this.shiftTimeWheelValue(field, -1);
      offset -= 25;
    } else if (offset <= -12.5) {
      this.shiftTimeWheelValue(field, 1);
      offset += 25;
    }
    this.setTimeWheelOffset(field, offset);
    this.getUIContext().animateTo({ duration: 140, curve: Curve.EaseOut }, () => {
      this.setTimeWheelOffset(field, 0);
    });
  }

  startTimeWheelPan(field: string): void {
    this.stopTimeWheelInertia();
    this.selectTimeField(field);
    this.wheelGestureField = field;
    this.wheelLastPanOffset = 0;
  }

  updateTimeWheelPan(field: string, offsetY: number): void {
    if (this.wheelGestureField !== field) this.startTimeWheelPan(field);
    const deltaY: number = offsetY - this.wheelLastPanOffset;
    this.wheelLastPanOffset = offsetY;
    this.applyTimeWheelDelta(field, deltaY);
  }

  endTimeWheelPan(field: string, velocityY: number): void {
    this.wheelLastPanOffset = 0;
    this.wheelGestureField = '';
    this.wheelInertiaVelocity = Math.max(-520, Math.min(520, velocityY * 0.45));
    if (Math.abs(this.wheelInertiaVelocity) < 45) {
      this.settleTimeWheel(field);
      return;
    }
    this.wheelInertiaTimer = setInterval(() => {
      this.applyTimeWheelDelta(field, this.wheelInertiaVelocity * 0.016);
      this.wheelInertiaVelocity *= 0.88;
      if (Math.abs(this.wheelInertiaVelocity) < 18) {
        this.stopTimeWheelInertia();
        this.settleTimeWheel(field);
      }
    }, 16);
  }

  onTimePickerChange(field: string, index: number): void {
    this.selectTimeField(field);
    if (field === 'hour') {
      this.customHour = index;
    } else {
      this.customMinute = index;
    }
  }

  @Builder
  timeNumberColumn(field: string) {
    Column({ space: 0 }) {
      Text(field === 'hour' ? '小时' : '分钟')
        .width('100%')
        .height(20)
        .fontSize(11)
        .fontColor(this.customTimeField === field ? '#67D89A' : '#AAB4AF')
        .textAlign(TextAlign.Center)
        .onClick(() => this.selectTimeField(field))

      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(44)
          .height(32)
          .backgroundColor(this.customTimeField === field ? '#263B32' : '#17211D')
          .borderRadius(13)

        Column({ space: 0 }) {
          Text(this.getTimePickerDisplayValue(field, -3))
            .width('100%').height(14).fontSize(8).fontColor('#56615B').textAlign(TextAlign.Center)
          Text(this.getTimePickerDisplayValue(field, -2))
            .width('100%').height(14).fontSize(8).fontColor('#56615B').textAlign(TextAlign.Center)
          Text(this.getTimePickerDisplayValue(field, -1))
            .width('100%').height(18).fontSize(10).fontColor('#76827C').textAlign(TextAlign.Center)
          Text(this.getTimePickerDisplayValue(field, 0))
            .width('100%').height(32).fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor(this.customTimeField === field ? '#67D89A' : '#F7FAF8').textAlign(TextAlign.Center)
          Text(this.getTimePickerDisplayValue(field, 1))
            .width('100%').height(18).fontSize(10).fontColor('#76827C').textAlign(TextAlign.Center)
          Text(this.getTimePickerDisplayValue(field, 2))
            .width('100%').height(14).fontSize(8).fontColor('#56615B').textAlign(TextAlign.Center)
          Text(this.getTimePickerDisplayValue(field, 3))
            .width('100%').height(14).fontSize(8).fontColor('#56615B').textAlign(TextAlign.Center)
        }
        .width(70)
        .height(124)
        .translate({ y: this.getTimeWheelOffset(field) })
      }
      .width(70)
      .height(96)
      .clip(true)
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 1 })
          .onActionStart(() => this.startTimeWheelPan(field))
          .onActionUpdate((event: GestureEvent) => this.updateTimeWheelPan(field, event.offsetY))
          .onActionEnd((event: GestureEvent) => this.endTimeWheelPan(field, event.velocityY))
          .onActionCancel(() => {
            this.wheelGestureField = '';
            this.wheelLastPanOffset = 0;
            this.settleTimeWheel(field);
          })
      )
    }
    .width(70)
    .height(114)
  }

  showNotificationStatus(message: string): void {
    this.notificationToastText = message;
    this.showNotificationToast = true;
    if (this.notificationToastTimer >= 0) {
      clearTimeout(this.notificationToastTimer);
    }
    this.notificationToastTimer = setTimeout(() => {
      this.showNotificationToast = false;
      this.notificationToastTimer = -1;
    }, 1200);
  }

  async cancelMealNotification(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders();
    } catch (error) {
      console.error(`cancel meal notification failed: ${JSON.stringify(error)}`);
    }
    this.mealReminderIds = [];
  }

  async scheduleMealNotifications(): Promise<boolean> {
    if (!this.notificationEnabled) {
      return false;
    }

    try {
      // Agent reminders only support selecting a slot type. They do not support setting
      // NotificationSlot.vibrationEnabled directly, so explicitly use the high-level service
      // information slot instead of allowing the system to fall back to an unknown/min slot.
      await reminderAgentManager.addNotificationSlot({
        notificationType: notificationManager.SlotType.SERVICE_INFORMATION
      });
      try {
        const reminderSlot: notificationManager.NotificationSlot = await notificationManager.getSlot(
          notificationManager.SlotType.SERVICE_INFORMATION);
        console.info(`meal reminder slot state: ${JSON.stringify(reminderSlot)}`);
      } catch (slotError) {
        // Slot creation is owned by the reminder-agent service. A failed diagnostic read must not
        // prevent the system-owned reminders from being scheduled.
        console.warn(`read meal reminder slot failed: ${JSON.stringify(slotError)}`);
      }

      // Update reminders already held by the system. Do not cancel them first: if the app is
      // terminated while rebuilding, the old background reminders must remain available.
      const existingReminders: Array<reminderAgentManager.ReminderInfo> =
        await reminderAgentManager.getAllValidReminders();
      const scheduledIds: number[] = [];
      const retainedReminderIds: number[] = [];
      const mealMinutes: number[] = [this.breakfastMinutes, this.lunchMinutes, this.dinnerMinutes];
      const everyMonth: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
      const everyDayOfMonth: number[] = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
      ];
      for (let index: number = 0; index < mealMinutes.length; index++) {
        const reminderMinutes: number = (mealMinutes[index] - 20 + 1440) % 1440;
        const mealName: string = this.getMealNotificationName(index);
        // Use a calendar notification, not an alarm. The system notification slot controls its haptic pattern.
        // Start at the next occurrence so rescheduling after a meal never fires an already elapsed reminder.
        const firstReminderDate: Date = new Date();
        firstReminderDate.setHours(Math.floor(reminderMinutes / 60), reminderMinutes % 60, 0, 0);
        if (firstReminderDate.getTime() <= Date.now()) {
          firstReminderDate.setDate(firstReminderDate.getDate() + 1);
        }
        const reminderRequest: reminderAgentManager.ReminderRequestCalendar = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
          dateTime: {
            year: firstReminderDate.getFullYear(),
            month: firstReminderDate.getMonth() + 1,
            day: firstReminderDate.getDate(),
            hour: Math.floor(reminderMinutes / 60),
            minute: reminderMinutes % 60,
            second: 0
          },
          repeatMonths: everyMonth,
          repeatDays: everyDayOfMonth,
          title: '就餐提醒',
          content: `距离${mealName}还有20分钟`,
          expiredContent: `${mealName}时间快到了`,
          notificationId: 2001 + index,
          slotType: notificationManager.SlotType.SERVICE_INFORMATION,
          actionButton: [{
            title: '删除',
            type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
          }],
          // Use the wearable's normal reminder channel, not an alarm slot. A one-second alert
          // lets the system play its notification haptic pattern; 0 suppresses that alert stage.
          ringDuration: 1,
          tapDismissed: true,
          wantAgent: {
            pkgName: 'com.lmmbb.foodnutrition',
            abilityName: 'EntryAbility'
          },
          // 设备未在使用时自动拉起提醒界面，使息屏状态能够亮屏提示。
          maxScreenWantAgent: {
            pkgName: 'com.lmmbb.foodnutrition',
            abilityName: 'EntryAbility'
          }
        };
        const existingReminder: reminderAgentManager.ReminderInfo | undefined = existingReminders.find(
          (info: reminderAgentManager.ReminderInfo) => info.reminderReq.notificationId === 2001 + index);
        if (existingReminder !== undefined) {
          await reminderAgentManager.updateReminder(existingReminder.reminderId, reminderRequest);
          scheduledIds.push(existingReminder.reminderId);
          retainedReminderIds.push(existingReminder.reminderId);
        } else {
          const reminderId: number = await reminderAgentManager.publishReminder(reminderRequest);
          scheduledIds.push(reminderId);
          retainedReminderIds.push(reminderId);
        }
      }

      // Remove only stale duplicate meal reminders after all current reminders are safely stored.
      for (let index: number = 0; index < existingReminders.length; index++) {
        const info: reminderAgentManager.ReminderInfo = existingReminders[index];
        const notificationId: number | undefined = info.reminderReq.notificationId;
        const isMealReminder: boolean = notificationId !== undefined &&
          notificationId >= 2001 && notificationId <= 2003;
        if (isMealReminder && retainedReminderIds.indexOf(info.reminderId) < 0) {
          await reminderAgentManager.cancelReminder(info.reminderId);
        }
      }
      this.mealReminderIds = scheduledIds;
      return true;
    } catch (error) {
      console.error(`schedule meal notification failed: ${JSON.stringify(error)}`);
      this.showNotificationStatus('提醒设置失败');
      return false;
    }
  }

  async checkNotificationVibrationSetting(): Promise<void> {
    try {
      const settings = await notificationManager.getNotificationSetting();
      const slot: notificationManager.NotificationSlot = await notificationManager.getSlot(
        notificationManager.SlotType.SERVICE_INFORMATION);
      if (!settings.vibrationEnabled || slot.enabled === false || slot.vibrationEnabled !== true) {
        this.showNotificationStatus('请在通知设置中开启服务提醒振动');
        const context: common.UIAbilityContext =
          this.getUIContext().getHostContext() as common.UIAbilityContext;
        await notificationManager.openNotificationSettings(context);
      } else {
        console.info('meal reminder vibration is enabled by both system and notification slot');
      }
    } catch (error) {
      console.warn(`read notification vibration setting failed: ${JSON.stringify(error)}`);
    }
  }

  async updateNotification(enabled: boolean): Promise<void> {
    if (!enabled) {
      this.notificationEnabled = false;
      await this.cancelMealNotification();
      await this.persistNotificationSetting(false);
      this.showNotificationStatus('通知已关闭');
      return;
    }

    try {
      let systemEnabled: boolean = await notificationManager.isNotificationEnabled();
      if (!systemEnabled) {
        const context: common.UIAbilityContext =
          this.getUIContext().getHostContext() as common.UIAbilityContext;
        await notificationManager.requestEnableNotification(context);
        systemEnabled = await notificationManager.isNotificationEnabled();
      }
      if (!systemEnabled) {
        this.notificationEnabled = false;
        this.showNotificationStatus('通知权限未开启');
        return;
      }

      this.notificationEnabled = true;
      const scheduled: boolean = await this.scheduleMealNotifications();
      if (scheduled) {
        const saved: boolean = await this.persistNotificationSetting(true);
        if (!saved) {
          this.notificationEnabled = false;
          await this.cancelMealNotification();
          this.showNotificationStatus('设置保存失败');
          return;
        }
        this.showNotificationStatus('通知已开启');
        await this.checkNotificationVibrationSetting();
      }
    } catch (error) {
      console.error(`request notification permission failed: ${JSON.stringify(error)}`);
      this.notificationEnabled = false;
      await this.persistNotificationSetting(false);
      this.showNotificationStatus('通知权限未开启');
    }
  }

  async saveCustomTime(): Promise<void> {
    const minutes: number = this.customHour * 60 + this.customMinute;
    const saved: boolean = await this.applyMealTime(this.editingMeal, minutes);
    if (!saved) {
      return;
    }
    this.showCustomTime = false;
    if (!this.customTimeFromInitialSetup) {
      this.showMealSettings = true;
    }
    this.customTimeFromInitialSetup = false;
  }

  getMealMinutes(index: number): number {
    if (index === 0) {
      return this.breakfastMinutes;
    }
    if (index === 1) {
      return this.lunchMinutes;
    }
    return this.dinnerMinutes;
  }

  getMealMinutesByKey(meal: string): number {
    if (meal === 'breakfast') {
      return this.breakfastMinutes;
    }
    if (meal === 'lunch') {
      return this.lunchMinutes;
    }
    return this.dinnerMinutes;
  }

  getMealName(index: number): string {
    if (index === 0) {
      return '早餐🌅';
    }
    if (index === 1) {
      return '午餐☀️';
    }
    return '晚餐🌙';
  }

  getMealNotificationName(index: number): string {
    if (index === 0) return '早餐';
    if (index === 1) return '午餐';
    return '晚餐';
  }

  getEditingMealName(): string {
    if (this.editingMeal === 'breakfast') {
      return '早餐🌅';
    }
    if (this.editingMeal === 'lunch') {
      return '午餐☀️';
    }
    return '晚餐🌙';
  }

  createMealTimestamp(minutes: number, addDay: boolean): number {
    const date: Date = new Date();
    date.setHours(Math.floor(minutes / 60), minutes % 60, 0, 0);
    if (addDay) {
      date.setDate(date.getDate() + 1);
    }
    return date.getTime();
  }

  initializeNextMeal(): void {
    const now: Date = new Date();
    const currentMinutes: number = now.getHours() * 60 + now.getMinutes();
    this.nowTimestamp = now.getTime();
    if (currentMinutes <= this.breakfastMinutes) {
      this.nextMealIndex = 0;
      this.nextMealTimestamp = this.createMealTimestamp(this.breakfastMinutes, false);
    } else if (currentMinutes <= this.lunchMinutes) {
      this.nextMealIndex = 1;
      this.nextMealTimestamp = this.createMealTimestamp(this.lunchMinutes, false);
    } else if (currentMinutes <= this.dinnerMinutes) {
      this.nextMealIndex = 2;
      this.nextMealTimestamp = this.createMealTimestamp(this.dinnerMinutes, false);
    } else {
      this.nextMealIndex = 0;
      this.nextMealTimestamp = this.createMealTimestamp(this.breakfastMinutes, true);
    }
  }

  syncNextMealTime(): void {
    if (this.nextMealTimestamp === 0) {
      return;
    }
    const date: Date = new Date(this.nextMealTimestamp);
    const minutes: number = this.getMealMinutes(this.nextMealIndex);
    date.setHours(Math.floor(minutes / 60), minutes % 60, 0, 0);
    this.nextMealTimestamp = date.getTime();
    this.nowTimestamp = Date.now();
    if (this.notificationEnabled) {
      this.scheduleMealNotifications();
    }
  }

  getCountdownMinutes(): number {
    const mealMinuteTimestamp: number = Math.floor(this.nextMealTimestamp / 60000);
    const currentMinuteTimestamp: number = Math.floor(this.nowTimestamp / 60000);
    return mealMinuteTimestamp - currentMinuteTimestamp;
  }

  getCountdownText(): string {
    const minutes: number = this.getCountdownMinutes();
    if (minutes <= 0) {
      return '请确认是否就餐';
    }
    if (minutes >= 60) {
      const hours: number = Math.floor(minutes / 60);
      const remainingMinutes: number = minutes % 60;
      return `还有 ${hours} 小时 ${remainingMinutes} 分钟`;
    }
    return `还有 ${minutes} 分钟`;
  }

  shouldHighlightCountdown(): boolean {
    return !this.allMealsCompleted && this.getCountdownMinutes() <= 20;
  }

  advanceToNextMeal(): void {
    const currentDate: Date = new Date(this.nextMealTimestamp);
    if (this.nextMealIndex === 0) {
      this.nextMealIndex = 1;
      currentDate.setHours(Math.floor(this.lunchMinutes / 60), this.lunchMinutes % 60, 0, 0);
    } else if (this.nextMealIndex === 1) {
      this.nextMealIndex = 2;
      currentDate.setHours(Math.floor(this.dinnerMinutes / 60), this.dinnerMinutes % 60, 0, 0);
    } else {
      this.allMealsCompleted = true;
      this.completionDayKey = this.getDayKey(Date.now());
      this.showMealConfirm = false;
      this.persistMealProgress(3);
      return;
    }
    this.nextMealTimestamp = currentDate.getTime();
    this.nowTimestamp = Date.now();
    this.showMealConfirm = false;
    this.persistMealProgress(this.nextMealIndex);
    if (this.notificationEnabled) {
      this.scheduleMealNotifications();
    }
  }

  @Builder
  energyOverview() {
    Column({ space: 2 }) {
      Row({ space: 3 }) {
        Text('‹')
          .width(18)
          .height(32)
          .fontSize(24)
          .fontColor('#AAB5AF')
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.dashboardNutrientIndex = (this.dashboardNutrientIndex + 3) % 4;
          })

        Stack({ alignContent: Alignment.Center }) {
          Progress({ value: Math.min(this.getDashboardNutrientValue(), this.getDashboardNutrientTarget()),
            total: this.getDashboardNutrientTarget(), type: ProgressType.Ring })
            .width(92)
            .height(92)
            .color(this.getDashboardNutrientColor())
            .backgroundColor('#22302B')
            .style({ strokeWidth: 7 })

          Column({ space: 0 }) {
            Text(this.getDashboardNutrientName())
              .fontSize(8)
              .fontColor('#8F9B95')
            Text(`${Math.round(this.getDashboardNutrientValue() * 10) / 10}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F7FAF8')
            Text(`${this.getDashboardNutrientUnit()} · ${Math.round(this.getDashboardNutrientValue() /
              this.getDashboardNutrientTarget() * 100)}%`)
              .fontSize(9)
              .fontColor('#78857F')
            Text(`剩余：${this.formatDashboardNutrientValue(this.getDashboardNutrientRemaining())}` +
              `${this.getDashboardNutrientUnit()}`)
              .fontSize(8)
              .fontColor(this.getDashboardNutrientColor())
          }
        }
        .width(92)
        .height(92)
        .onClick(() => {
          router.pushUrl({ url: 'pages/NutritionDetail' });
        })

        Text('›')
          .width(18)
          .height(32)
          .fontSize(24)
          .fontColor('#AAB5AF')
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.dashboardNutrientIndex = (this.dashboardNutrientIndex + 1) % 4;
          })
      }
      .width(140)
      .height(92)
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        Column({ space: 0 }) {
          Text('每日目标')
            .fontSize(7)
            .fontColor('#7F8B86')
          Text(`${this.formatDashboardNutrientValue(this.getDashboardNutrientTarget())} ` +
            this.getDashboardNutrientUnit())
            .fontSize(8)
            .fontWeight(FontWeight.Medium)
            .fontColor('#DDE4E0')
            .maxLines(1)
        }
        .width(56)

        Column({ space: 0 }) {
          Text('剩余可摄入')
            .fontSize(7)
            .fontColor('#7F8B86')
          Text(`${this.formatDashboardNutrientValue(this.getDashboardNutrientRemaining())} ` +
            this.getDashboardNutrientUnit())
            .fontSize(8)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getDashboardNutrientColor())
            .maxLines(1)
        }
        .width(56)
      }
      .width(126)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height(116)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  mealReminder() {
    Row() {
      Column({ space: 0 }) {
        Text(this.allMealsCompleted ? '今日餐次已完成' : `下一餐 · ${this.getMealName(this.nextMealIndex)}`)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F4F7F5')
        Text(this.allMealsCompleted ? '早餐、午餐、晚餐均已确认' :
          `${this.formatTime(this.getMealMinutes(this.nextMealIndex))} · ${this.getCountdownText()}`)
          .fontSize(8)
          .fontWeight(this.shouldHighlightCountdown() ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.allMealsCompleted ? '#67D89A' :
            (this.shouldHighlightCountdown() ? '#F5C96A' : '#8E9A94'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.allMealsCompleted ? '✓' : '›')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#67D89A')
    }
    .width('70%')
    .height(32)
    .padding({ left: 12, right: 10 })
    .backgroundColor('#18211E')
    .border({ width: 1, color: this.allMealsCompleted ? '#315F49' :
      (this.shouldHighlightCountdown() ? '#796A3C' : '#24312C') })
    .borderRadius(19)
    .onClick(() => {
      this.showMealConfirm = true;
    })
  }

  @Builder
  foodRecordButton() {
    Button('+ 记录饮食')
      .width(76)
      .height(28)
      .fontSize(10)
      .fontWeight(FontWeight.Bold)
      .fontColor('#092117')
      .backgroundColor('#67D89A')
      .borderRadius(14)
      .padding({ left: 4, right: 4 })
      .stateEffect(true)
      .onClick(() => {
        this.openFoodRecord();
      })
  }

  @Builder
  actionButtons() {
    Row({ space: 6 }) {
      this.foodRecordButton()

      Button('其他功能')
        .width(70)
        .height(28)
        .fontSize(9)
        .fontColor('#CFD7D3')
        .backgroundColor('#252F2B')
        .border({ width: 1, color: '#34413B' })
        .borderRadius(14)
        .padding({ left: 4, right: 4 })
        .stateEffect(true)
        .onClick(() => {
          this.showSettings = false;
          this.showQuickMenu = true;
        })
    }
  }

  @Builder
  menuButton(title: string) {
    Button(title)
      .width(70)
      .height(30)
      .fontSize(9)
      .fontColor('#E8ECEA')
      .backgroundColor('#27312E')
      .borderRadius(12)
      .stateEffect(true)
      .onClick(() => {
        if (title === '营养详情') {
          this.showQuickMenu = false;
          router.pushUrl({ url: 'pages/NutritionDetail' });
        } else if (title === '历史趋势') {
          this.showQuickMenu = false;
          router.pushUrl({ url: 'pages/HistoryTrend' });
        }
      })
  }

  @Builder
  todayNutritionMenuButton() {
    Button('今日营养')
      .width(70)
      .height(30)
      .fontSize(9)
      .fontColor('#E8ECEA')
      .backgroundColor('#27312E')
      .borderRadius(12)
      .stateEffect(true)
      .onClick(() => {
        this.showQuickMenu = false;
        router.pushUrl({ url: 'pages/TodayNutrition' });
      })
  }

  @Builder
  settingsMenuButton() {
    Button('应用设置')
      .width(70)
      .height(30)
      .fontSize(9)
      .fontColor('#E8ECEA')
      .backgroundColor('#27312E')
      .borderRadius(12)
      .stateEffect(true)
      .onClick(() => {
        this.showQuickMenu = false;
        this.showMealSettings = false;
        this.showCustomTime = false;
        this.showSettings = true;
      })
  }

  @Builder
  quickMenu() {
    Column({ space: 7 }) {
      Text('其他功能')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')

      Row({ space: 7 }) {
        this.todayNutritionMenuButton()
        this.menuButton('营养详情')
      }

      Row({ space: 7 }) {
        this.menuButton('历史趋势')
        this.settingsMenuButton()
      }

      Button('关闭')
        .width(70)
        .height(26)
        .fontSize(9)
        .fontColor('#092117')
        .backgroundColor('#67D89A')
        .borderRadius(13)
        .stateEffect(true)
        .onClick(() => {
          this.showQuickMenu = false;
        })
    }
    .width(176)
    .padding({ top: 10, right: 10, bottom: 9, left: 10 })
    .backgroundColor('#F2131A18')
    .border({ width: 1, color: '#34403B' })
    .borderRadius(26)
  }

  @Builder
  mealTimeRow(label: string, meal: string) {
    Row({ space: 6 }) {
      Text(label)
        .width(48)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor('#DDE4E0')

      Text(this.formatTime(this.getMealMinutesByKey(meal)))
        .width(48)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#67D89A')
        .textAlign(TextAlign.Center)

      Button('自定义')
        .width(58)
        .height(26)
        .fontSize(9)
        .fontColor('#70C9FF')
        .backgroundColor('#202C28')
        .borderRadius(13)
        .padding({ left: 4, right: 4 })
        .stateEffect(true)
        .onClick(() => {
          this.openCustomTime(meal, this.getMealMinutesByKey(meal));
        })
    }
    .width(176)
    .height(38)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#18211E')
    .border({ width: 1, color: '#28342F' })
    .borderRadius(17)
  }

  @Builder
  settingsPanel() {
    Column({ space: 3 }) {
      Text('应用设置')
        .width('68%')
        .height(32)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)

      Scroll(this.pageScroller) {
        Column({ space: 7 }) {
          Row() {
            Column({ space: 1 }) {
              Text('就餐设置')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#F4F7F5')
              Text('早餐、午餐、晚餐时间')
                .fontSize(9)
                .fontColor('#AAB5AF')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(18)
              .fontColor('#67D89A')
          }
          .width('74%')
          .height(44)
          .padding({ left: 13, right: 11 })
          .backgroundColor('#18211E')
          .border({ width: 1, color: '#28342F' })
          .borderRadius(20)
          .onClick(() => {
            this.showSettings = false;
            this.showMealSettings = true;
          })

          Row() {
            Column({ space: 1 }) {
              Text('通知提醒')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#F4F7F5')
              Text(this.notificationEnabled ? '通知已开启' : '通知已关闭')
                .fontSize(8)
                .fontColor(this.notificationEnabled ? '#67D89A' : '#8F9B95')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.notificationEnabled })
              .width(34)
              .height(20)
              .selectedColor('#67D89A')
              .switchPointColor('#F4F7F5')
              .onChange((isOn: boolean) => {
                this.updateNotification(isOn);
              })
          }
          .width('74%')
          .height(44)
          .padding({ left: 13, right: 11 })
          .backgroundColor('#18211E')
          .border({ width: 1, color: '#28342F' })
          .borderRadius(20)

          Row() {
            Column({ space: 1 }) {
              Text('营养目标')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#F4F7F5')
              Text('热量与三大营养素目标')
                .fontSize(8)
                .fontColor('#8F9B95')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(18)
              .fontColor('#67D89A')
          }
          .width('74%')
          .height(44)
          .padding({ left: 13, right: 11 })
          .backgroundColor('#18211E')
          .border({ width: 1, color: '#28342F' })
          .borderRadius(20)
          .onClick(() => {
            this.editingCalorieTarget = this.dailyCalorieTarget;
            this.calorieTargetInput = `${this.dailyCalorieTarget}`;
            this.editingCarbohydrateTarget = this.dailyCarbohydrateTarget;
            this.carbohydrateTargetInput = `${this.dailyCarbohydrateTarget}`;
            this.editingProteinTarget = this.dailyProteinTarget;
            this.proteinTargetInput = `${this.dailyProteinTarget}`;
            this.editingFatTarget = this.dailyFatTarget;
            this.fatTargetInput = `${this.dailyFatTarget}`;
            this.showSettings = false;
            this.showNutritionSettings = true;
          })

          Row() {
            Column({ space: 1 }) {
              Text('隐私权限')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#F4F7F5')
              Text('管理应用权限与隐私')
                .fontSize(8)
                .fontColor('#8F9B95')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(18)
              .fontColor('#67D89A')
          }
          .width('74%')
          .height(44)
          .padding({ left: 13, right: 11 })
          .backgroundColor('#18211E')
          .border({ width: 1, color: '#28342F' })
          .borderRadius(20)
          .onClick(() => {
            this.showSettings = false;
            this.showPrivacyPermissions = true;
          })

          Row() {
            Column({ space: 1 }) {
              Text('关于应用')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#F4F7F5')
              Text('版本与数据来源')
                .fontSize(8)
                .fontColor('#8F9B95')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(18)
              .fontColor('#67D89A')
          }
          .width('74%')
          .height(44)
          .padding({ left: 13, right: 11 })
          .backgroundColor('#18211E')
          .border({ width: 1, color: '#28342F' })
          .borderRadius(20)
          .onClick(() => {
            this.showSettings = false;
            this.showAboutApp = true;
          })

          Row() {
            Column({ space: 1 }) {
              Text('问题反馈')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#F4F7F5')
              Text('反馈使用过程中遇到的问题')
                .fontSize(8)
                .fontColor('#8F9B95')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Text('›')
              .fontSize(18)
              .fontColor('#67D89A')
          }
          .width('74%')
          .height(44)
          .padding({ left: 13, right: 11 })
          .backgroundColor('#18211E')
          .border({ width: 1, color: '#28342F' })
          .borderRadius(20)
          .onClick(() => {
            this.showSettings = false;
            this.showFeedback = true;
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 5, bottom: 34 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 30 })
    .backgroundColor('#0A0E0C')
  }

  @Builder
  privacyPermissionsPage() {
    Column({ space: 6 }) {
      Text('隐私权限')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)

      Text('扫码查看隐私政策')
        .fontSize(9)
        .fontColor('#DDE4E0')

      Image($r('app.media.privacy_qr'))
        .width(108)
        .height(108)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#FFFFFF')
        .borderRadius(6)

      Button('返回')
        .width(70)
        .height(27)
        .fontSize(9)
        .fontColor('#092117')
        .backgroundColor('#67D89A')
        .borderRadius(14)
        .onClick(() => {
          this.showPrivacyPermissions = false;
          this.showSettings = true;
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#0A0E0C')
  }

  @Builder
  aboutAppPage() {
    Column({ space: 10 }) {
      Text('关于应用')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)

      Row() {
        Text('应用版本')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F4F7F5')
          .layoutWeight(1)
        Text('›')
          .fontSize(18)
          .fontColor('#67D89A')
      }
      .width('74%')
      .height(44)
      .padding({ left: 13, right: 11 })
      .backgroundColor('#18211E')
      .border({ width: 1, color: '#28342F' })
      .borderRadius(20)
      .onClick(() => {
        this.showAboutApp = false;
        this.showAppVersion = true;
      })

      Row() {
        Text('数据来源说明')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F4F7F5')
          .layoutWeight(1)
        Text('›')
          .fontSize(18)
          .fontColor('#67D89A')
      }
      .width('74%')
      .height(44)
      .padding({ left: 13, right: 11 })
      .backgroundColor('#18211E')
      .border({ width: 1, color: '#28342F' })
      .borderRadius(20)
      .onClick(() => {
        this.showAboutApp = false;
        this.showDataSource = true;
      })

      Button('返回')
        .width(70)
        .height(27)
        .fontSize(9)
        .fontColor('#092117')
        .backgroundColor('#67D89A')
        .borderRadius(14)
        .onClick(() => {
          this.showAboutApp = false;
          this.showSettings = true;
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#0A0E0C')
  }

  @Builder
  appVersionPage() {
    Column({ space: 14 }) {
      Text('应用版本')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')

      Column({ space: 4 }) {
        Text('食刻营养')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#DDE4E0')
        Text('V1.0.0')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#DDE4E0')
      }
      .alignItems(HorizontalAlign.Center)

      Button('返回')
        .width(70)
        .height(27)
        .fontSize(9)
        .fontColor('#092117')
        .backgroundColor('#67D89A')
        .borderRadius(14)
        .onClick(() => {
          this.showAppVersion = false;
          this.showAboutApp = true;
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#0A0E0C')
  }

  @Builder
  dataSourcePage() {
    Column({ space: 14 }) {
      Text('数据来源说明')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')

      Text('应用内食物营养数据主要参考公开发布的《中国食物成分表》及用户自行录入的信息。由于食物品种、产地、加工和烹饪方式不同，实际营养含量可能存在差异，相关数据仅用于日常饮食记录与参考，不作为医疗诊断或治疗依据。')
        .width('76%')
        .fontSize(9)
        .fontColor('#DDE4E0')
        .lineHeight(14)
        .textAlign(TextAlign.Start)

      Button('返回')
        .width(70)
        .height(27)
        .fontSize(9)
        .fontColor('#092117')
        .backgroundColor('#67D89A')
        .borderRadius(14)
        .onClick(() => {
          this.showDataSource = false;
          this.showAboutApp = true;
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#0A0E0C')
  }

  @Builder
  feedbackPage() {
    Column({ space: 8 }) {
      Text('问题反馈')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')

      Column({ space: 4 }) {
        Text('QQ反馈群号：')
          .width('100%')
          .fontSize(10)
          .fontColor('#DDE4E0')
          .textAlign(TextAlign.Center)
        Text('1127552336')
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F7FAF8')
          .textAlign(TextAlign.Center)
        Text('')
          .width('100%')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F7FAF8')
          .textAlign(TextAlign.Center)
        Text('邮箱反馈：')
          .width('100%')
          .fontSize(10)
          .fontColor('#DDE4E0')
          .textAlign(TextAlign.Center)
        Text('2798025402@qq.com')
          .width('100%')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F7FAF8')
          .textAlign(TextAlign.Center)
      }
      .width('78%')
      .alignItems(HorizontalAlign.Center)

      Button('返回')
        .width(70)
        .height(27)
        .fontSize(9)
        .fontColor('#092117')
        .backgroundColor('#67D89A')
        .borderRadius(14)
        .onClick(() => {
          this.showFeedback = false;
          this.showSettings = true;
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#0A0E0C')
  }

  @Builder
  privacyConsentPage() {
    Column({ space: 7 }) {
      Text('隐私政策')
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)

      Text('请用手机扫码查看')
        .width('100%')
        .fontSize(8)
        .fontColor('#8F9B95')
        .textAlign(TextAlign.Center)

      Image($r('app.media.privacy_qr'))
        .width(108)
        .height(108)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#FFFFFF')
        .borderRadius(6)

      Row({ space: 8 }) {
        Button('不同意')
          .width(70)
          .height(25)
          .fontSize(9)
          .fontColor('#DDE4E0')
          .backgroundColor('#28332F')
          .borderRadius(13)
          .onClick(() => { this.rejectPrivacyConsent(); })
        Button('同意')
          .width(70)
          .height(25)
          .fontSize(9)
          .fontColor('#092117')
          .backgroundColor('#67D89A')
          .borderRadius(13)
          .onClick(() => { this.acceptPrivacyConsent(); })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 16, bottom: 14 })
    .backgroundColor('#0A0E0C')
  }

  @Builder
  initialSetupPage() {
    Column({ space: 5 }) {
      Text('首次设置')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')

      Text('请先设置每日就餐时间')
        .fontSize(9)
        .fontColor('#AAB5AF')

      this.mealTimeRow('早餐🌅', 'breakfast')
      this.mealTimeRow('午餐☀️', 'lunch')
      this.mealTimeRow('晚餐🌙', 'dinner')

      Button('完成设置')
        .width(78)
        .height(27)
        .fontSize(9)
        .fontWeight(FontWeight.Medium)
        .fontColor('#092117')
        .backgroundColor('#67D89A')
        .borderRadius(14)
        .onClick(() => {
          this.completeInitialSetup();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#0A0E0C')
  }

  @Builder
  loadingPage() {
    Column({ space: 8 }) {
      Progress({ value: 45, total: 100, type: ProgressType.Ring })
        .width(34)
        .height(34)
        .color('#67D89A')
        .backgroundColor('#22302B')
        .style({ strokeWidth: 4 })
      Text('正在读取设置')
        .fontSize(8)
        .fontColor('#8F9B95')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#0A0E0C')
  }

  @Builder
  nutritionValueRow(label: string, kind: string, step: number, minimum: number, maximum: number) {
    Row({ space: 5 }) {
      Text(label)
        .width(46)
        .fontSize(9)
        .fontColor('#DDE4E0')
      Button('-')
        .width(28)
        .height(24)
        .fontSize(11)
        .backgroundColor('#28332F')
        .borderRadius(11)
        .padding(0)
        .onClick(() => {
          this.setEditingNutritionTarget(kind,
            Math.max(minimum, this.getEditingNutritionTarget(kind) - step));
        })
      TextInput({ text: this.getNutritionTargetInput(kind) })
        .width(44)
        .height(24)
        .type(InputType.Number)
        .maxLength(5)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(kind === 'calories' ? '#67D89A' : '#5BC0EB')
        .textAlign(TextAlign.Center)
        .backgroundColor(Color.Transparent)
        .padding(0)
        .caretColor(kind === 'calories' ? '#67D89A' : '#5BC0EB')
        .onChange((value: string) => {
          const digits: string = value.replace(/[^0-9]/g, '');
          this.setNutritionTargetInput(kind, digits);
        })
        .onBlur(() => {
          this.clampNutritionTargetInput(kind);
        })
      Button('+')
        .width(28)
        .height(24)
        .fontSize(11)
        .backgroundColor('#28332F')
        .borderRadius(11)
        .padding(0)
        .onClick(() => {
          this.setEditingNutritionTarget(kind,
            Math.min(maximum, this.getEditingNutritionTarget(kind) + step));
        })
    }
    .width(174)
    .height(27)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#18211E')
    .borderRadius(15)
  }

  @Builder
  nutritionSettingsPage() {
    Column({ space: 2 }) {
      Text('营养目标')
        .width(174)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)

      Text('设置每日摄入目标，营养素单位为克（g）')
        .fontSize(7)
        .fontColor('#8F9B95')

      this.nutritionValueRow('热量 kcal', 'calories', 50, 500, 10000)
      this.nutritionValueRow('碳水 g', 'carbohydrate', 5, 1, 1000)
      this.nutritionValueRow('蛋白质 g', 'protein', 5, 1, 500)
      this.nutritionValueRow('脂肪 g', 'fat', 5, 1, 500)

      Row({ space: 3 }) {
        Text('ⓘ')
          .fontSize(9)
          .fontWeight(FontWeight.Medium)
          .fontColor('#67D89A')
          .onClick(() => {
            this.showNutritionSettings = false;
            this.showNutritionGuide = true;
          })
        Text('设置指南')
          .fontSize(8)
          .fontColor('#AEB9B3')
      }
      .width(154)
      .height(14)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      Row({ space: 6 }) {
        Button('取消')
          .width(54)
          .height(24)
          .fontSize(9)
          .backgroundColor('#28332F')
          .borderRadius(13)
          .onClick(() => {
            this.showNutritionSettings = false;
            this.showSettings = true;
          })
        Button('保存')
          .width(64)
          .height(24)
          .fontSize(9)
          .fontColor('#092117')
          .backgroundColor('#67D89A')
          .borderRadius(13)
          .onClick(() => { this.saveNutritionSettings(); })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#0A0E0C')
  }

  @Builder
  nutritionGuidePage() {
    Column({ space: 3 }) {
      Text('设置指南')
        .width('100%')
        .height(28)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)

      Scroll(this.pageScroller) {
        Column({ space: 8 }) {
          Text('　　以下数值适用于一般健康成年人，可作为每日饮食规划的参考，并不代表所有人的固定需要量。实际需求会受到性别、年龄、体重、身体活动量及健康状况影响。')
            .width('78%')
            .fontSize(10)
            .fontColor('#DDE4E0')
            .lineHeight(15)
            .textAlign(TextAlign.Start)

          Text('宏量营养素')
            .width('78%')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#67D89A')

          Text('　　热量：女性约1800 kcal；男性约2250 kcal（轻身体活动水平）\n' +
            '　　蛋白质：女性55 g；男性65 g\n' +
            '　　碳水化合物：占总能量的50%～65%，女性约225～293 g，男性约281～366 g\n' +
            '　　脂肪：占总能量的20%～30%，女性约40～60 g，男性约50～75 g\n' +
            '　　膳食纤维：25～30 g\n' +
            '　　胆固醇：健康成年人暂无统一的每日固定上限；血脂异常或心血管疾病高风险人群应遵循医生指导')
            .width('78%')
            .fontSize(10)
            .fontColor('#DDE4E0')
            .lineHeight(16)
            .textAlign(TextAlign.Start)

          Text('维生素')
            .width('78%')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#67D89A')

          Text('　　维生素A：女性700 μg RAE；男性800 μg RAE\n' +
            '　　维生素B1：女性1.2 mg；男性1.4 mg\n' +
            '　　维生素B2：女性1.2 mg；男性1.4 mg\n' +
            '　　维生素C：100 mg\n' +
            '　　维生素E：14 mg α-TE')
            .width('78%')
            .fontSize(10)
            .fontColor('#DDE4E0')
            .lineHeight(16)
            .textAlign(TextAlign.Start)

          Text('矿物质')
            .width('78%')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#67D89A')

          Text('　　钙：800 mg\n' +
            '　　磷：720 mg\n' +
            '　　钾：2000 mg\n' +
            '　　钠：适宜摄入量1500 mg，同时建议每日食盐少于5 g\n' +
            '　　镁：330 mg\n' +
            '　　铁：女性20 mg；男性12 mg\n' +
            '　　锌：女性7.5 mg；男性12.5 mg\n' +
            '　　硒：60 μg\n' +
            '　　铜：0.8 mg\n' +
            '　　锰：4.5 mg')
            .width('78%')
            .fontSize(10)
            .fontColor('#DDE4E0')
            .lineHeight(16)
            .textAlign(TextAlign.Start)

          Text('饮食建议')
            .width('78%')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#67D89A')

          Text('　　建议保持食物多样、谷类为主，每天摄入蔬菜300～500 g、水果200～350 g、奶及奶制品约300 g、鱼禽肉蛋合计120～200 g。烹调油25～30 g，食盐少于5 g，并尽量减少添加糖。')
            .width('78%')
            .fontSize(10)
            .fontColor('#DDE4E0')
            .lineHeight(15)
            .textAlign(TextAlign.Start)

          Text('数据参考：《中国居民膳食指南（2022）》及国家卫生健康委《中国居民膳食营养素参考摄入量》。孕妇、乳母、老年人、未成年人及慢性疾病人群应遵循医生或营养师建议。\n\n')
            .width('78%')
            .fontSize(9)
            .fontColor('#8F9B95')
            .lineHeight(14)
            .textAlign(TextAlign.Start)

          // Text('')
          //   .width('78%')
          //   .fontSize(9)
          //   .fontColor('#8F9B95')
          //   .lineHeight(14)
          //   .textAlign(TextAlign.Start)

        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 4, bottom: 30 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.None)
    }
    .width('100%')
    .height('100%')
    .padding({ top: 24 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
    .backgroundColor('#0A0E0C')
  }

  @Builder
  mealSettingsPage() {
    Column({ space: 3 }) {
      Text('就餐设置')
        .width('68%')
        .height(28)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')
        .textAlign(TextAlign.Center)

      Text('点击自定义后转动表冠设置小时和分钟')
        .width(176)
        .fontSize(9)
        .fontColor('#AAB5AF')
        .textAlign(TextAlign.Center)

      this.mealTimeRow('早餐🌅', 'breakfast')
      this.mealTimeRow('午餐☀️', 'lunch')
      this.mealTimeRow('晚餐🌙', 'dinner')

      Button('完成')
        .width(72)
        .height(26)
        .fontSize(9)
        .fontColor('#092117')
        .backgroundColor('#67D89A')
        .borderRadius(13)
        .onClick(() => {
          this.showMealSettings = false;
          this.showSettings = true;
        })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 26, bottom: 24 })
    .backgroundColor('#0A0E0C')
  }

  @Builder
  customTimePanel() {
    Column({ space: 4 }) {
      Text('设置时间')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F7FAF8')

      Row({ space: 5 }) {
        Text(this.getEditingMealName())
          .width('100%')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#AAB4AF')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Row({ space: 2 }) {
        this.timeNumberColumn('hour')
        Text(':')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FAF8')
          .margin({ top: 18 })
        this.timeNumberColumn('minute')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Row({ space: 8 }) {
        Button('取消')
          .width(68)
          .height(26)
          .fontSize(9)
          .fontColor('#D5DCD8')
          .backgroundColor('#28332F')
          .borderRadius(15)
          .onClick(() => {
            this.showCustomTime = false;
            if (!this.customTimeFromInitialSetup) {
              this.showMealSettings = true;
            }
            this.customTimeFromInitialSetup = false;
          })

        Button('确定')
          .width(68)
          .height(26)
          .fontSize(9)
          .fontWeight(FontWeight.Medium)
          .fontColor('#092117')
          .backgroundColor('#67D89A')
          .borderRadius(15)
          .onClick(() => {
            this.saveCustomTime();
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 0, bottom: 24 })
    .backgroundColor('#0A0E0C')
  }

  @Builder
  mealConfirmPanel() {
    Column({ space: 6 }) {
      if (this.allMealsCompleted) {
        Text('今日餐次已完成')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#67D89A')

        Text('早餐、午餐、晚餐均已确认')
          .fontSize(9)
          .fontColor('#C9D2CD')

        Text('明天将自动恢复下一餐提醒')
          .fontSize(8)
          .fontColor('#7F8B86')

        Button('知道了')
          .width(70)
          .height(26)
          .fontSize(9)
          .fontColor('#092117')
          .backgroundColor('#67D89A')
          .borderRadius(13)
          .onClick(() => {
            this.showMealConfirm = false;
          })
      } else {
        Text('确认就餐')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F7FAF8')

        Text(`${this.getMealName(this.nextMealIndex)} · ${this.formatTime(this.getMealMinutes(this.nextMealIndex))}`)
          .fontSize(10)
          .fontColor('#F5C96A')

        this.foodRecordButton()

        Text('当前直接确认，并进入下一餐')
          .fontSize(8)
          .fontColor('#7F8B86')

        Row({ space: 7 }) {
          Button('取消')
            .width(58)
            .height(26)
            .fontSize(9)
            .fontColor('#D5DCD8')
            .backgroundColor('#28332F')
            .borderRadius(13)
            .onClick(() => {
              this.showMealConfirm = false;
            })

          Button('确认已就餐')
            .width(78)
            .height(26)
            .fontSize(9)
            .fontColor('#092117')
            .backgroundColor('#67D89A')
            .borderRadius(13)
            .padding({ left: 3, right: 3 })
            .onClick(() => {
              this.advanceToNextMeal();
            })
        }
      }

    }
    .width(180)
    .padding({ top: 11, right: 10, bottom: 10, left: 10 })
    .backgroundColor('#F2131A18')
    .border({ width: 1, color: '#34403B' })
    .borderRadius(26)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (!this.settingsLoaded) {
        this.loadingPage()
      } else if (this.showPrivacyConsent) {
        this.privacyConsentPage()
      } else if (this.showCustomTime) {
        this.customTimePanel()
      } else if (this.showInitialSetup) {
        this.initialSetupPage()
      } else if (this.showNutritionGuide) {
        this.nutritionGuidePage()
      } else if (this.showNutritionSettings) {
        this.nutritionSettingsPage()
      } else if (this.showAppVersion) {
        this.appVersionPage()
      } else if (this.showDataSource) {
        this.dataSourcePage()
      } else if (this.showAboutApp) {
        this.aboutAppPage()
      } else if (this.showFeedback) {
        this.feedbackPage()
      } else if (this.showPrivacyPermissions) {
        this.privacyPermissionsPage()
      } else if (this.showSettings) {
        this.settingsPanel()
      } else if (this.showMealSettings) {
        this.mealSettingsPage()
      } else {
        Scroll(this.pageScroller) {
          Column({ space: 4 }) {
            this.mealReminder()
            this.energyOverview()
            this.actionButtons()
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 24, bottom: 24 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)

        if (this.showQuickMenu) {
          Column() {
            this.quickMenu()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#D90A0E0C')
        }

        if (this.showMealConfirm) {
          Column() {
            this.mealConfirmPanel()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#D90A0E0C')
        }
      }

      if (this.showNotificationToast) {
        Text(this.notificationToastText)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .padding({ top: 7, right: 14, bottom: 7, left: 14 })
          .backgroundColor('#F05D6561')
          .border({ width: 1, color: '#8A777F7B' })
          .borderRadius(15)
          .shadow({ radius: 10, color: '#99000000', offsetX: 0, offsetY: 3 })
          .zIndex(100)
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
