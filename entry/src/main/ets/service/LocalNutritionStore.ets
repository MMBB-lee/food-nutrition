import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { DailyNutritionSummary, FoodRecord, NutritionHistoryDay,
  NutritionTargetSnapshot } from '../model/NutritionModels';

const PREFERENCES_NAME: string = 'meal_settings';
const FOOD_RECORDS_KEY: string = 'foodRecords';
const CALORIE_TARGET_KEY: string = 'calorieTarget';
const CARBOHYDRATE_TARGET_KEY: string = 'carbohydrateTarget';
const PROTEIN_TARGET_KEY: string = 'proteinTarget';
const FAT_TARGET_KEY: string = 'fatTarget';
const CALORIE_TARGET_HISTORY_KEY: string = 'calorieTargetHistory';
const CARBOHYDRATE_TARGET_HISTORY_KEY: string = 'carbohydrateTargetHistory';
const PROTEIN_TARGET_HISTORY_KEY: string = 'proteinTargetHistory';
const FAT_TARGET_HISTORY_KEY: string = 'fatTargetHistory';
const FIRST_USE_DAY_KEY: string = 'firstUseDayKey';
const COMPLETION_DAY_KEY: string = 'completionDayKey';
const NEXT_MEAL_INDEX_KEY: string = 'nextMealIndex';
const BREAKFAST_MINUTES_KEY: string = 'breakfastMinutes';
const LUNCH_MINUTES_KEY: string = 'lunchMinutes';
const DINNER_MINUTES_KEY: string = 'dinnerMinutes';

export class LocalNutritionStore {
  static getDayKey(timestamp: number = Date.now()): string {
    const date: Date = new Date(timestamp);
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }

  private static async getStore(context: common.Context): Promise<preferences.Preferences> {
    return preferences.getPreferences(context, { name: PREFERENCES_NAME });
  }

  static async getAllFoodRecords(context: common.Context): Promise<FoodRecord[]> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    const value: string = await store.get(FOOD_RECORDS_KEY, '[]') as string;
    try {
      const records: FoodRecord[] = JSON.parse(value) as FoodRecord[];
      const cutoff: Date = new Date();
      cutoff.setHours(0, 0, 0, 0);
      cutoff.setDate(cutoff.getDate() - 29);
      const cutoffTime: number = cutoff.getTime();
      const retainedRecords: FoodRecord[] = records.filter((record: FoodRecord) => {
        const parts: string[] = record.dayKey.split('-');
        const recordDate: Date = parts.length >= 3 ?
          new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])) :
          new Date(record.recordedAt);
        recordDate.setHours(0, 0, 0, 0);
        return !Number.isNaN(recordDate.getTime()) && recordDate.getTime() >= cutoffTime;
      });
      if (retainedRecords.length !== records.length) {
        try {
          await store.put(FOOD_RECORDS_KEY, JSON.stringify(retainedRecords));
          await store.flush();
        } catch (error) {
          console.error(`prune old food records failed: ${JSON.stringify(error)}`);
        }
      }
      return retainedRecords;
    } catch (error) {
      console.error(`parse food records failed: ${JSON.stringify(error)}`);
      return [];
    }
  }

  static async getFoodRecordsByDay(context: common.Context, dayKey: string): Promise<FoodRecord[]> {
    const records: FoodRecord[] = await LocalNutritionStore.getAllFoodRecords(context);
    return records.filter((record: FoodRecord) => record.dayKey === dayKey);
  }

  static async getFirstUseDayKey(context: common.Context): Promise<string> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    const savedDayKey: string = await store.get(FIRST_USE_DAY_KEY, '') as string;
    if (savedDayKey.length > 0) return savedDayKey;

    const today: string = LocalNutritionStore.getDayKey();
    const todayTime: number = LocalNutritionStore.getTargetDayTime(today);
    let firstUseTime: number = todayTime;
    const recordsJson: string = await store.get(FOOD_RECORDS_KEY, '[]') as string;
    try {
      const records: FoodRecord[] = JSON.parse(recordsJson) as FoodRecord[];
      records.forEach((record: FoodRecord) => {
        const recordTime: number = LocalNutritionStore.getTargetDayTime(record.dayKey);
        if (!Number.isNaN(recordTime) && recordTime <= todayTime && recordTime < firstUseTime) {
          firstUseTime = recordTime;
        }
      });
    } catch (error) {
      console.error(`parse food records while initializing first use day failed: ${JSON.stringify(error)}`);
    }

    const historyKeys: string[] = [
      CALORIE_TARGET_HISTORY_KEY,
      CARBOHYDRATE_TARGET_HISTORY_KEY,
      PROTEIN_TARGET_HISTORY_KEY,
      FAT_TARGET_HISTORY_KEY
    ];
    for (let index: number = 0; index < historyKeys.length; index++) {
      const historyJson: string = await store.get(historyKeys[index], '[]') as string;
      const history: NutritionTargetSnapshot[] = LocalNutritionStore.parseTargetHistory(historyJson);
      history.forEach((item: NutritionTargetSnapshot) => {
        const itemTime: number = LocalNutritionStore.getTargetDayTime(item.dayKey);
        if (!Number.isNaN(itemTime) && itemTime <= todayTime && itemTime < firstUseTime) {
          firstUseTime = itemTime;
        }
      });
    }

    const firstUseDayKey: string = LocalNutritionStore.getDayKey(firstUseTime);
    await store.put(FIRST_USE_DAY_KEY, firstUseDayKey);
    await store.flush();
    return firstUseDayKey;
  }

  private static isSameMealFood(existing: FoodRecord, incoming: FoodRecord): boolean {
    if (existing.dayKey !== incoming.dayKey || existing.mealIndex !== incoming.mealIndex) return false;
    if (incoming.foodCode.length > 0) return existing.foodCode === incoming.foodCode;
    return existing.foodName === incoming.foodName && existing.category === incoming.category;
  }

  private static addNutrientValue(first: number, second: number): number {
    return Math.round((first + second) * 10) / 10;
  }

  private static mergeFoodRecord(target: FoodRecord, source: FoodRecord): void {
    target.weight = LocalNutritionStore.addNutrientValue(target.weight, source.weight);
    target.energyKCal = Math.round(target.energyKCal + source.energyKCal);
    target.protein = LocalNutritionStore.addNutrientValue(target.protein, source.protein);
    target.fat = LocalNutritionStore.addNutrientValue(target.fat, source.fat);
    target.carbohydrate = LocalNutritionStore.addNutrientValue(target.carbohydrate, source.carbohydrate);
    target.dietaryFiber = LocalNutritionStore.addNutrientValue(target.dietaryFiber, source.dietaryFiber);
    target.cholesterol = LocalNutritionStore.addNutrientValue(target.cholesterol, source.cholesterol);
    target.vitaminA = LocalNutritionStore.addNutrientValue(target.vitaminA, source.vitaminA);
    target.thiamin = LocalNutritionStore.addNutrientValue(target.thiamin, source.thiamin);
    target.riboflavin = LocalNutritionStore.addNutrientValue(target.riboflavin, source.riboflavin);
    target.niacin = LocalNutritionStore.addNutrientValue(target.niacin, source.niacin);
    target.vitaminC = LocalNutritionStore.addNutrientValue(target.vitaminC, source.vitaminC);
    target.vitaminETotal = LocalNutritionStore.addNutrientValue(target.vitaminETotal, source.vitaminETotal);
    target.calcium = LocalNutritionStore.addNutrientValue(target.calcium, source.calcium);
    target.phosphorus = LocalNutritionStore.addNutrientValue(target.phosphorus, source.phosphorus);
    target.potassium = LocalNutritionStore.addNutrientValue(target.potassium, source.potassium);
    target.sodium = LocalNutritionStore.addNutrientValue(target.sodium, source.sodium);
    target.magnesium = LocalNutritionStore.addNutrientValue(target.magnesium, source.magnesium);
    target.iron = LocalNutritionStore.addNutrientValue(target.iron, source.iron);
    target.zinc = LocalNutritionStore.addNutrientValue(target.zinc, source.zinc);
    target.selenium = LocalNutritionStore.addNutrientValue(target.selenium, source.selenium);
    target.copper = LocalNutritionStore.addNutrientValue(target.copper, source.copper);
    target.manganese = LocalNutritionStore.addNutrientValue(target.manganese, source.manganese);
  }

  static async addFoodRecord(context: common.Context, record: FoodRecord): Promise<void> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    const records: FoodRecord[] = await LocalNutritionStore.getAllFoodRecords(context);
    const existing: FoodRecord | undefined = records.find(
      (item: FoodRecord) => LocalNutritionStore.isSameMealFood(item, record));
    if (existing === undefined) {
      records.push(record);
    } else {
      for (let index: number = records.length - 1; index >= 0; index--) {
        const item: FoodRecord = records[index];
        if (item.id !== existing.id && LocalNutritionStore.isSameMealFood(item, record)) {
          LocalNutritionStore.mergeFoodRecord(existing, item);
          records.splice(index, 1);
        }
      }
      LocalNutritionStore.mergeFoodRecord(existing, record);
    }
    await store.put(FOOD_RECORDS_KEY, JSON.stringify(records));
    await store.flush();
  }

  private static async saveFoodRecords(context: common.Context, records: FoodRecord[]): Promise<void> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    await store.put(FOOD_RECORDS_KEY, JSON.stringify(records));
    await store.flush();
  }

  static async deleteFoodRecord(context: common.Context, recordId: string): Promise<void> {
    const records: FoodRecord[] = await LocalNutritionStore.getAllFoodRecords(context);
    const remainingRecords: FoodRecord[] = records.filter((record: FoodRecord) => record.id !== recordId);
    await LocalNutritionStore.saveFoodRecords(context, remainingRecords);
  }

  static async updateFoodRecordWeight(context: common.Context, recordId: string, newWeight: number): Promise<void> {
    const records: FoodRecord[] = await LocalNutritionStore.getAllFoodRecords(context);
    const record: FoodRecord | undefined = records.find((item: FoodRecord) => item.id === recordId);
    if (record === undefined || record.weight <= 0) return;
    const ratio: number = newWeight / record.weight;
    record.weight = newWeight;
    record.energyKCal = Math.round(record.energyKCal * ratio);
    record.protein = LocalNutritionStore.scaleNutrient(record.protein, ratio);
    record.fat = LocalNutritionStore.scaleNutrient(record.fat, ratio);
    record.carbohydrate = LocalNutritionStore.scaleNutrient(record.carbohydrate, ratio);
    record.dietaryFiber = LocalNutritionStore.scaleNutrient(record.dietaryFiber, ratio);
    record.cholesterol = LocalNutritionStore.scaleNutrient(record.cholesterol, ratio);
    record.vitaminA = LocalNutritionStore.scaleNutrient(record.vitaminA, ratio);
    record.thiamin = LocalNutritionStore.scaleNutrient(record.thiamin, ratio);
    record.riboflavin = LocalNutritionStore.scaleNutrient(record.riboflavin, ratio);
    record.niacin = LocalNutritionStore.scaleNutrient(record.niacin, ratio);
    record.vitaminC = LocalNutritionStore.scaleNutrient(record.vitaminC, ratio);
    record.vitaminETotal = LocalNutritionStore.scaleNutrient(record.vitaminETotal, ratio);
    record.calcium = LocalNutritionStore.scaleNutrient(record.calcium, ratio);
    record.phosphorus = LocalNutritionStore.scaleNutrient(record.phosphorus, ratio);
    record.potassium = LocalNutritionStore.scaleNutrient(record.potassium, ratio);
    record.sodium = LocalNutritionStore.scaleNutrient(record.sodium, ratio);
    record.magnesium = LocalNutritionStore.scaleNutrient(record.magnesium, ratio);
    record.iron = LocalNutritionStore.scaleNutrient(record.iron, ratio);
    record.zinc = LocalNutritionStore.scaleNutrient(record.zinc, ratio);
    record.selenium = LocalNutritionStore.scaleNutrient(record.selenium, ratio);
    record.copper = LocalNutritionStore.scaleNutrient(record.copper, ratio);
    record.manganese = LocalNutritionStore.scaleNutrient(record.manganese, ratio);
    await LocalNutritionStore.saveFoodRecords(context, records);
  }

  private static scaleNutrient(value: number, ratio: number): number {
    return Math.round(value * ratio * 10) / 10;
  }

  static summarize(records: FoodRecord[]): DailyNutritionSummary {
    let calories: number = 0;
    let protein: number = 0;
    let fat: number = 0;
    let carbohydrate: number = 0;
    records.forEach((record: FoodRecord) => {
      calories += record.energyKCal;
      protein += record.protein;
      fat += record.fat;
      carbohydrate += record.carbohydrate;
    });
    return {
      calories: Math.round(calories),
      protein: Math.round(protein * 10) / 10,
      fat: Math.round(fat * 10) / 10,
      carbohydrate: Math.round(carbohydrate * 10) / 10
    };
  }

  static async getCalorieTarget(context: common.Context): Promise<number> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    return await store.get(CALORIE_TARGET_KEY, 1800) as number;
  }

  private static async setTargetWithHistory(context: common.Context, targetKey: string,
    historyKey: string, target: number, defaultTarget: number): Promise<void> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    const previousTarget: number = await store.get(targetKey, defaultTarget) as number;
    const historyJson: string = await store.get(historyKey, '[]') as string;
    let history: NutritionTargetSnapshot[] = LocalNutritionStore.parseTargetHistory(historyJson);
    const cutoff: Date = new Date();
    cutoff.setHours(0, 0, 0, 0);
    cutoff.setDate(cutoff.getDate() - 29);
    const cutoffTime: number = cutoff.getTime();
    const today: string = LocalNutritionStore.getDayKey();
    const todayTime: number = LocalNutritionStore.getTargetDayTime(today);
    const hasBaseline: boolean = history.some((item: NutritionTargetSnapshot) =>
      LocalNutritionStore.getTargetDayTime(item.dayKey) <= cutoffTime);
    if (!hasBaseline) {
      const hasPreviousChange: boolean = history.some((item: NutritionTargetSnapshot) =>
        LocalNutritionStore.getTargetDayTime(item.dayKey) > cutoffTime &&
        LocalNutritionStore.getTargetDayTime(item.dayKey) < todayTime);
      history.push({
        dayKey: LocalNutritionStore.getDayKey(cutoffTime),
        target: hasPreviousChange ? defaultTarget : previousTarget
      });
    }
    history = history.filter((item: NutritionTargetSnapshot) => item.dayKey !== today);
    history.push({ dayKey: today, target: target });
    history = LocalNutritionStore.retainRecentTargets(history, cutoff);
    await store.put(targetKey, target);
    await store.put(historyKey, JSON.stringify(history));
    await store.flush();
  }

  static async setCalorieTarget(context: common.Context, calories: number): Promise<void> {
    await LocalNutritionStore.setTargetWithHistory(
      context, CALORIE_TARGET_KEY, CALORIE_TARGET_HISTORY_KEY, calories, 1800);
  }

  static async getCarbohydrateTarget(context: common.Context): Promise<number> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    return await store.get(CARBOHYDRATE_TARGET_KEY, 250) as number;
  }

  static async setCarbohydrateTarget(context: common.Context, grams: number): Promise<void> {
    await LocalNutritionStore.setTargetWithHistory(
      context, CARBOHYDRATE_TARGET_KEY, CARBOHYDRATE_TARGET_HISTORY_KEY, grams, 250);
  }

  static async getProteinTarget(context: common.Context): Promise<number> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    return await store.get(PROTEIN_TARGET_KEY, 60) as number;
  }

  static async setProteinTarget(context: common.Context, grams: number): Promise<void> {
    await LocalNutritionStore.setTargetWithHistory(
      context, PROTEIN_TARGET_KEY, PROTEIN_TARGET_HISTORY_KEY, grams, 60);
  }

  static async getFatTarget(context: common.Context): Promise<number> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    return await store.get(FAT_TARGET_KEY, 60) as number;
  }

  static async setFatTarget(context: common.Context, grams: number): Promise<void> {
    await LocalNutritionStore.setTargetWithHistory(
      context, FAT_TARGET_KEY, FAT_TARGET_HISTORY_KEY, grams, 60);
  }

  private static parseTargetHistory(historyJson: string): NutritionTargetSnapshot[] {
    try {
      return JSON.parse(historyJson) as NutritionTargetSnapshot[];
    } catch (error) {
      console.error(`parse nutrition target history failed: ${JSON.stringify(error)}`);
      return [];
    }
  }

  private static getTargetDayTime(dayKey: string): number {
    if (typeof dayKey !== 'string') return Number.NaN;
    const parts: string[] = dayKey.split('-');
    if (parts.length < 3) return Number.NaN;
    const year: number = Number(parts[0]);
    const month: number = Number(parts[1]);
    const day: number = Number(parts[2]);
    if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day) ||
      month < 1 || month > 12 || day < 1 || day > 31) return Number.NaN;
    const date: Date = new Date(year, month - 1, day);
    if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
      return Number.NaN;
    }
    return date.getTime();
  }

  private static retainRecentTargets(history: NutritionTargetSnapshot[], cutoff: Date): NutritionTargetSnapshot[] {
    const recent: NutritionTargetSnapshot[] = [];
    let baseline: NutritionTargetSnapshot | undefined = undefined;
    let baselineTime: number = -1;
    history.forEach((item: NutritionTargetSnapshot) => {
      const itemTime: number = LocalNutritionStore.getTargetDayTime(item.dayKey);
      if (Number.isNaN(itemTime)) return;
      if (itemTime >= cutoff.getTime()) {
        recent.push(item);
      } else if (itemTime >= baselineTime) {
        baseline = item;
        baselineTime = itemTime;
      }
    });
    if (baseline !== undefined) recent.unshift(baseline);
    return recent;
  }

  private static getTargetForDay(history: NutritionTargetSnapshot[], dayKey: string,
    currentTarget: number, defaultTarget: number): number {
    const targetTime: number = LocalNutritionStore.getTargetDayTime(dayKey);
    if (Number.isNaN(targetTime)) return currentTarget;
    let matchedTarget: number = history.length === 0 ? currentTarget : defaultTarget;
    let matchedTime: number = -1;
    history.forEach((item: NutritionTargetSnapshot) => {
      const itemTime: number = LocalNutritionStore.getTargetDayTime(item.dayKey);
      if (itemTime <= targetTime && itemTime >= matchedTime) {
        matchedTime = itemTime;
        matchedTarget = item.target;
      }
    });
    return matchedTarget;
  }

  static async getNutritionHistory(context: common.Context, dayCount: number): Promise<NutritionHistoryDay[]> {
    const records: FoodRecord[] = await LocalNutritionStore.getAllFoodRecords(context);
    const firstUseDayKey: string = await LocalNutritionStore.getFirstUseDayKey(context);
    const firstUseTime: number = LocalNutritionStore.getTargetDayTime(firstUseDayKey);
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    const currentCalorieTarget: number = await store.get(CALORIE_TARGET_KEY, 1800) as number;
    const currentCarbohydrateTarget: number = await store.get(CARBOHYDRATE_TARGET_KEY, 250) as number;
    const currentProteinTarget: number = await store.get(PROTEIN_TARGET_KEY, 60) as number;
    const currentFatTarget: number = await store.get(FAT_TARGET_KEY, 60) as number;
    let calorieTargetHistory: NutritionTargetSnapshot[] = LocalNutritionStore.parseTargetHistory(
      await store.get(CALORIE_TARGET_HISTORY_KEY, '[]') as string);
    let carbohydrateTargetHistory: NutritionTargetSnapshot[] = LocalNutritionStore.parseTargetHistory(
      await store.get(CARBOHYDRATE_TARGET_HISTORY_KEY, '[]') as string);
    let proteinTargetHistory: NutritionTargetSnapshot[] = LocalNutritionStore.parseTargetHistory(
      await store.get(PROTEIN_TARGET_HISTORY_KEY, '[]') as string);
    let fatTargetHistory: NutritionTargetSnapshot[] = LocalNutritionStore.parseTargetHistory(
      await store.get(FAT_TARGET_HISTORY_KEY, '[]') as string);
    const cutoff: Date = new Date();
    cutoff.setHours(0, 0, 0, 0);
    cutoff.setDate(cutoff.getDate() - 29);
    const retainedCalorieTargets: NutritionTargetSnapshot[] =
      LocalNutritionStore.retainRecentTargets(calorieTargetHistory, cutoff);
    const retainedCarbohydrateTargets: NutritionTargetSnapshot[] =
      LocalNutritionStore.retainRecentTargets(carbohydrateTargetHistory, cutoff);
    const retainedProteinTargets: NutritionTargetSnapshot[] =
      LocalNutritionStore.retainRecentTargets(proteinTargetHistory, cutoff);
    const retainedFatTargets: NutritionTargetSnapshot[] =
      LocalNutritionStore.retainRecentTargets(fatTargetHistory, cutoff);
    const targetHistoryChanged: boolean = retainedCalorieTargets.length !== calorieTargetHistory.length ||
      retainedCarbohydrateTargets.length !== carbohydrateTargetHistory.length ||
      retainedProteinTargets.length !== proteinTargetHistory.length ||
      retainedFatTargets.length !== fatTargetHistory.length;
    calorieTargetHistory = retainedCalorieTargets;
    carbohydrateTargetHistory = retainedCarbohydrateTargets;
    proteinTargetHistory = retainedProteinTargets;
    fatTargetHistory = retainedFatTargets;
    if (targetHistoryChanged) {
      await store.put(CALORIE_TARGET_HISTORY_KEY, JSON.stringify(calorieTargetHistory));
      await store.put(CARBOHYDRATE_TARGET_HISTORY_KEY, JSON.stringify(carbohydrateTargetHistory));
      await store.put(PROTEIN_TARGET_HISTORY_KEY, JSON.stringify(proteinTargetHistory));
      await store.put(FAT_TARGET_HISTORY_KEY, JSON.stringify(fatTargetHistory));
      await store.flush();
    }

    const days: NutritionHistoryDay[] = [];
    const today: Date = new Date();
    today.setHours(0, 0, 0, 0);
    for (let offset: number = Math.min(29, Math.max(0, dayCount - 1)); offset >= 0; offset--) {
      const date: Date = new Date(today.getTime());
      date.setDate(date.getDate() - offset);
      const dayKey: string = LocalNutritionStore.getDayKey(date.getTime());
      const beforeFirstUse: boolean = LocalNutritionStore.getTargetDayTime(dayKey) < firstUseTime;
      const dayRecords: FoodRecord[] = records.filter((record: FoodRecord) => record.dayKey === dayKey);
      const summary: DailyNutritionSummary = LocalNutritionStore.summarize(dayRecords);
      days.push({
        dayKey: dayKey,
        calories: summary.calories,
        calorieTarget: beforeFirstUse ? 0 : LocalNutritionStore.getTargetForDay(
          calorieTargetHistory, dayKey, currentCalorieTarget, 1800),
        carbohydrate: summary.carbohydrate,
        carbohydrateTarget: beforeFirstUse ? 0 : LocalNutritionStore.getTargetForDay(
          carbohydrateTargetHistory, dayKey, currentCarbohydrateTarget, 250),
        fat: summary.fat,
        fatTarget: beforeFirstUse ? 0 : LocalNutritionStore.getTargetForDay(fatTargetHistory, dayKey, currentFatTarget, 60),
        protein: summary.protein,
        proteinTarget: beforeFirstUse ? 0 : LocalNutritionStore.getTargetForDay(
          proteinTargetHistory, dayKey, currentProteinTarget, 60)
      });
    }
    return days;
  }

  static async saveMealProgress(context: common.Context, completionDayKey: string,
    nextMealIndex: number): Promise<void> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    await store.put(COMPLETION_DAY_KEY, completionDayKey);
    await store.put(NEXT_MEAL_INDEX_KEY, nextMealIndex);
    await store.flush();
  }

  static async getCompletionDayKey(context: common.Context): Promise<string> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    return await store.get(COMPLETION_DAY_KEY, '') as string;
  }

  static async getSavedNextMealIndex(context: common.Context): Promise<number> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    return await store.get(NEXT_MEAL_INDEX_KEY, -1) as number;
  }

  static calculateAutomaticNextMealIndex(breakfastMinutes: number, lunchMinutes: number,
    dinnerMinutes: number, timestamp: number = Date.now()): number {
    const now: Date = new Date(timestamp);
    const currentMinutes: number = now.getHours() * 60 + now.getMinutes();
    if (currentMinutes > dinnerMinutes + 60) return 3;
    if (currentMinutes > lunchMinutes + 60) return 2;
    if (currentMinutes > breakfastMinutes + 60) return 1;
    return 0;
  }

  static async resolveMealProgress(context: common.Context, breakfastMinutes: number,
    lunchMinutes: number, dinnerMinutes: number, timestamp: number = Date.now()): Promise<number> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    const today: string = LocalNutritionStore.getDayKey(timestamp);
    const savedDay: string = await store.get(COMPLETION_DAY_KEY, '') as string;
    const savedIndex: number = await store.get(NEXT_MEAL_INDEX_KEY, -1) as number;
    const manualIndex: number = savedDay === today ? Math.max(0, Math.min(3, savedIndex)) : 0;
    const automaticIndex: number = LocalNutritionStore.calculateAutomaticNextMealIndex(
      breakfastMinutes, lunchMinutes, dinnerMinutes, timestamp);
    const resolvedIndex: number = Math.max(manualIndex, automaticIndex);
    if (savedDay !== today || savedIndex !== resolvedIndex) {
      await store.put(COMPLETION_DAY_KEY, today);
      await store.put(NEXT_MEAL_INDEX_KEY, resolvedIndex);
      await store.flush();
    }
    return resolvedIndex;
  }

  static async resolveMealProgressFromSettings(context: common.Context,
    timestamp: number = Date.now()): Promise<number> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    const breakfastMinutes: number = await store.get(BREAKFAST_MINUTES_KEY, 480) as number;
    const lunchMinutes: number = await store.get(LUNCH_MINUTES_KEY, 720) as number;
    const dinnerMinutes: number = await store.get(DINNER_MINUTES_KEY, 1080) as number;
    return LocalNutritionStore.resolveMealProgress(
      context, breakfastMinutes, lunchMinutes, dinnerMinutes, timestamp);
  }
}
