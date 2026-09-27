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
    historyKey: string, target: number): Promise<void> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    await store.put(targetKey, target);
    const historyJson: string = await store.get(historyKey, '[]') as string;
    let history: NutritionTargetSnapshot[] = [];
    try {
      history = JSON.parse(historyJson) as NutritionTargetSnapshot[];
    } catch (error) {
      console.error(`parse nutrition target history failed: ${JSON.stringify(error)}`);
    }
    const today: string = LocalNutritionStore.getDayKey();
    history = history.filter((item: NutritionTargetSnapshot) => item.dayKey !== today);
    history.push({ dayKey: today, target: target });
    await store.put(historyKey, JSON.stringify(history));
    await store.flush();
  }

  static async setCalorieTarget(context: common.Context, calories: number): Promise<void> {
    await LocalNutritionStore.setTargetWithHistory(
      context, CALORIE_TARGET_KEY, CALORIE_TARGET_HISTORY_KEY, calories);
  }

  static async getCarbohydrateTarget(context: common.Context): Promise<number> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    return await store.get(CARBOHYDRATE_TARGET_KEY, 250) as number;
  }

  static async setCarbohydrateTarget(context: common.Context, grams: number): Promise<void> {
    await LocalNutritionStore.setTargetWithHistory(
      context, CARBOHYDRATE_TARGET_KEY, CARBOHYDRATE_TARGET_HISTORY_KEY, grams);
  }

  static async getProteinTarget(context: common.Context): Promise<number> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    return await store.get(PROTEIN_TARGET_KEY, 60) as number;
  }

  static async setProteinTarget(context: common.Context, grams: number): Promise<void> {
    await LocalNutritionStore.setTargetWithHistory(
      context, PROTEIN_TARGET_KEY, PROTEIN_TARGET_HISTORY_KEY, grams);
  }

  static async getFatTarget(context: common.Context): Promise<number> {
    const store: preferences.Preferences = await LocalNutritionStore.getStore(context);
    return await store.get(FAT_TARGET_KEY, 60) as number;
  }

  static async setFatTarget(context: common.Context, grams: number): Promise<void> {
    await LocalNutritionStore.setTargetWithHistory(
      context, FAT_TARGET_KEY, FAT_TARGET_HISTORY_KEY, grams);
  }

  private static parseTargetHistory(historyJson: string): NutritionTargetSnapshot[] {
    try {
      return JSON.parse(historyJson) as NutritionTargetSnapshot[];
    } catch (error) {
      console.error(`parse nutrition target history failed: ${JSON.stringify(error)}`);
      return [];
    }
  }

  private static retainRecentTargets(history: NutritionTargetSnapshot[], cutoff: Date): NutritionTargetSnapshot[] {
    return history.filter((item: NutritionTargetSnapshot) => {
      const parts: string[] = item.dayKey.split('-');
      if (parts.length < 3) return false;
      const date: Date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
      date.setHours(0, 0, 0, 0);
      return date.getTime() >= cutoff.getTime();
    });
  }

  private static getTargetForDay(history: NutritionTargetSnapshot[], dayKey: string,
    currentTarget: number): number {
    const targetParts: string[] = dayKey.split('-');
    if (targetParts.length < 3) return currentTarget;
    const targetTime: number = new Date(
      Number(targetParts[0]), Number(targetParts[1]) - 1, Number(targetParts[2])).getTime();
    let matchedTarget: number = currentTarget;
    let matchedTime: number = -1;
    history.forEach((item: NutritionTargetSnapshot) => {
      const parts: string[] = item.dayKey.split('-');
      if (parts.length < 3) return;
      const itemTime: number = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])).getTime();
      if (itemTime <= targetTime && itemTime >= matchedTime) {
        matchedTime = itemTime;
        matchedTarget = item.target;
      }
    });
    return matchedTarget;
  }

  static async getNutritionHistory(context: common.Context, dayCount: number): Promise<NutritionHistoryDay[]> {
    const records: FoodRecord[] = await LocalNutritionStore.getAllFoodRecords(context);
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
      const dayRecords: FoodRecord[] = records.filter((record: FoodRecord) => record.dayKey === dayKey);
      const summary: DailyNutritionSummary = LocalNutritionStore.summarize(dayRecords);
      days.push({
        dayKey: dayKey,
        calories: summary.calories,
        calorieTarget: LocalNutritionStore.getTargetForDay(
          calorieTargetHistory, dayKey, currentCalorieTarget),
        carbohydrate: summary.carbohydrate,
        carbohydrateTarget: LocalNutritionStore.getTargetForDay(
          carbohydrateTargetHistory, dayKey, currentCarbohydrateTarget),
        fat: summary.fat,
        fatTarget: LocalNutritionStore.getTargetForDay(fatTargetHistory, dayKey, currentFatTarget),
        protein: summary.protein,
        proteinTarget: LocalNutritionStore.getTargetForDay(proteinTargetHistory, dayKey, currentProteinTarget)
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
