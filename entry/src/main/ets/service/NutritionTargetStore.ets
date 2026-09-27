import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { DailyNutritionSummary, FoodRecord, NutritionHistoryDay,
  NutritionTargetSnapshot } from '../model/NutritionModels';
import { FoodRecordStore } from './FoodRecordStore';
import { NutritionDateUtils } from './NutritionDateUtils';
import { CALORIE_TARGET_HISTORY_KEY, CALORIE_TARGET_KEY, CARBOHYDRATE_TARGET_HISTORY_KEY,
  CARBOHYDRATE_TARGET_KEY, FAT_TARGET_HISTORY_KEY, FAT_TARGET_KEY, FIRST_USE_DAY_KEY,
  FOOD_RECORDS_KEY, NutritionPreferences, PROTEIN_TARGET_HISTORY_KEY,
  PROTEIN_TARGET_KEY } from './NutritionPreferences';

export class NutritionTargetStore {
  static async getFirstUseDayKey(context: common.Context): Promise<string> {
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
    const savedDayKey: string = await store.get(FIRST_USE_DAY_KEY, '') as string;
    if (savedDayKey.length > 0) return savedDayKey;

    const today: string = NutritionDateUtils.getDayKey();
    const todayTime: number = NutritionDateUtils.getDayStartTime(today);
    let firstUseTime: number = todayTime;
    const recordsJson: string = await store.get(FOOD_RECORDS_KEY, '[]') as string;
    try {
      const records: FoodRecord[] = JSON.parse(recordsJson) as FoodRecord[];
      records.forEach((record: FoodRecord) => {
        const recordTime: number = NutritionDateUtils.getDayStartTime(record.dayKey);
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
      const history: NutritionTargetSnapshot[] = NutritionTargetStore.parseHistory(historyJson);
      history.forEach((item: NutritionTargetSnapshot) => {
        const itemTime: number = NutritionDateUtils.getDayStartTime(item.dayKey);
        if (!Number.isNaN(itemTime) && itemTime <= todayTime && itemTime < firstUseTime) {
          firstUseTime = itemTime;
        }
      });
    }

    const firstUseDayKey: string = NutritionDateUtils.getDayKey(firstUseTime);
    await store.put(FIRST_USE_DAY_KEY, firstUseDayKey);
    await store.flush();
    return firstUseDayKey;
  }

  static async getCalorieTarget(context: common.Context): Promise<number> {
    return NutritionTargetStore.getTarget(context, CALORIE_TARGET_KEY, 1800);
  }

  static async setCalorieTarget(context: common.Context, calories: number): Promise<void> {
    await NutritionTargetStore.setTargetWithHistory(
      context, CALORIE_TARGET_KEY, CALORIE_TARGET_HISTORY_KEY, calories, 1800);
  }

  static async getCarbohydrateTarget(context: common.Context): Promise<number> {
    return NutritionTargetStore.getTarget(context, CARBOHYDRATE_TARGET_KEY, 250);
  }

  static async setCarbohydrateTarget(context: common.Context, grams: number): Promise<void> {
    await NutritionTargetStore.setTargetWithHistory(
      context, CARBOHYDRATE_TARGET_KEY, CARBOHYDRATE_TARGET_HISTORY_KEY, grams, 250);
  }

  static async getProteinTarget(context: common.Context): Promise<number> {
    return NutritionTargetStore.getTarget(context, PROTEIN_TARGET_KEY, 60);
  }

  static async setProteinTarget(context: common.Context, grams: number): Promise<void> {
    await NutritionTargetStore.setTargetWithHistory(
      context, PROTEIN_TARGET_KEY, PROTEIN_TARGET_HISTORY_KEY, grams, 60);
  }

  static async getFatTarget(context: common.Context): Promise<number> {
    return NutritionTargetStore.getTarget(context, FAT_TARGET_KEY, 60);
  }

  static async setFatTarget(context: common.Context, grams: number): Promise<void> {
    await NutritionTargetStore.setTargetWithHistory(
      context, FAT_TARGET_KEY, FAT_TARGET_HISTORY_KEY, grams, 60);
  }

  static async getHistory(context: common.Context, dayCount: number): Promise<NutritionHistoryDay[]> {
    const records: FoodRecord[] = await FoodRecordStore.getAll(context);
    const firstUseDayKey: string = await NutritionTargetStore.getFirstUseDayKey(context);
    const firstUseTime: number = NutritionDateUtils.getDayStartTime(firstUseDayKey);
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
    const currentCalorieTarget: number = await store.get(CALORIE_TARGET_KEY, 1800) as number;
    const currentCarbohydrateTarget: number = await store.get(CARBOHYDRATE_TARGET_KEY, 250) as number;
    const currentProteinTarget: number = await store.get(PROTEIN_TARGET_KEY, 60) as number;
    const currentFatTarget: number = await store.get(FAT_TARGET_KEY, 60) as number;
    let calorieTargetHistory: NutritionTargetSnapshot[] = NutritionTargetStore.parseHistory(
      await store.get(CALORIE_TARGET_HISTORY_KEY, '[]') as string);
    let carbohydrateTargetHistory: NutritionTargetSnapshot[] = NutritionTargetStore.parseHistory(
      await store.get(CARBOHYDRATE_TARGET_HISTORY_KEY, '[]') as string);
    let proteinTargetHistory: NutritionTargetSnapshot[] = NutritionTargetStore.parseHistory(
      await store.get(PROTEIN_TARGET_HISTORY_KEY, '[]') as string);
    let fatTargetHistory: NutritionTargetSnapshot[] = NutritionTargetStore.parseHistory(
      await store.get(FAT_TARGET_HISTORY_KEY, '[]') as string);
    const cutoff: Date = new Date();
    cutoff.setHours(0, 0, 0, 0);
    cutoff.setDate(cutoff.getDate() - 29);
    const retainedCalorieTargets: NutritionTargetSnapshot[] =
      NutritionTargetStore.retainRecentTargets(calorieTargetHistory, cutoff);
    const retainedCarbohydrateTargets: NutritionTargetSnapshot[] =
      NutritionTargetStore.retainRecentTargets(carbohydrateTargetHistory, cutoff);
    const retainedProteinTargets: NutritionTargetSnapshot[] =
      NutritionTargetStore.retainRecentTargets(proteinTargetHistory, cutoff);
    const retainedFatTargets: NutritionTargetSnapshot[] =
      NutritionTargetStore.retainRecentTargets(fatTargetHistory, cutoff);
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
      const dayKey: string = NutritionDateUtils.getDayKey(date.getTime());
      const beforeFirstUse: boolean = NutritionDateUtils.getDayStartTime(dayKey) < firstUseTime;
      const dayRecords: FoodRecord[] = records.filter((record: FoodRecord) => record.dayKey === dayKey);
      const summary: DailyNutritionSummary = FoodRecordStore.summarize(dayRecords);
      days.push({
        dayKey: dayKey,
        calories: summary.calories,
        calorieTarget: beforeFirstUse ? 0 : NutritionTargetStore.getTargetForDay(
          calorieTargetHistory, dayKey, currentCalorieTarget, 1800),
        carbohydrate: summary.carbohydrate,
        carbohydrateTarget: beforeFirstUse ? 0 : NutritionTargetStore.getTargetForDay(
          carbohydrateTargetHistory, dayKey, currentCarbohydrateTarget, 250),
        fat: summary.fat,
        fatTarget: beforeFirstUse ? 0 : NutritionTargetStore.getTargetForDay(
          fatTargetHistory, dayKey, currentFatTarget, 60),
        protein: summary.protein,
        proteinTarget: beforeFirstUse ? 0 : NutritionTargetStore.getTargetForDay(
          proteinTargetHistory, dayKey, currentProteinTarget, 60)
      });
    }
    return days;
  }

  private static async getTarget(context: common.Context, key: string, defaultTarget: number): Promise<number> {
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
    return await store.get(key, defaultTarget) as number;
  }

  private static async setTargetWithHistory(context: common.Context, targetKey: string,
    historyKey: string, target: number, defaultTarget: number): Promise<void> {
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
    const previousTarget: number = await store.get(targetKey, defaultTarget) as number;
    const historyJson: string = await store.get(historyKey, '[]') as string;
    let history: NutritionTargetSnapshot[] = NutritionTargetStore.parseHistory(historyJson);
    const cutoff: Date = new Date();
    cutoff.setHours(0, 0, 0, 0);
    cutoff.setDate(cutoff.getDate() - 29);
    const cutoffTime: number = cutoff.getTime();
    const today: string = NutritionDateUtils.getDayKey();
    const todayTime: number = NutritionDateUtils.getDayStartTime(today);
    const hasBaseline: boolean = history.some((item: NutritionTargetSnapshot) =>
      NutritionDateUtils.getDayStartTime(item.dayKey) <= cutoffTime);
    if (!hasBaseline) {
      const hasPreviousChange: boolean = history.some((item: NutritionTargetSnapshot) =>
        NutritionDateUtils.getDayStartTime(item.dayKey) > cutoffTime &&
        NutritionDateUtils.getDayStartTime(item.dayKey) < todayTime);
      history.push({
        dayKey: NutritionDateUtils.getDayKey(cutoffTime),
        target: hasPreviousChange ? defaultTarget : previousTarget
      });
    }
    history = history.filter((item: NutritionTargetSnapshot) => item.dayKey !== today);
    history.push({ dayKey: today, target: target });
    history = NutritionTargetStore.retainRecentTargets(history, cutoff);
    await store.put(targetKey, target);
    await store.put(historyKey, JSON.stringify(history));
    await store.flush();
  }

  private static parseHistory(historyJson: string): NutritionTargetSnapshot[] {
    try {
      return JSON.parse(historyJson) as NutritionTargetSnapshot[];
    } catch (error) {
      console.error(`parse nutrition target history failed: ${JSON.stringify(error)}`);
      return [];
    }
  }

  private static retainRecentTargets(history: NutritionTargetSnapshot[], cutoff: Date): NutritionTargetSnapshot[] {
    const recent: NutritionTargetSnapshot[] = [];
    let baseline: NutritionTargetSnapshot | undefined = undefined;
    let baselineTime: number = -1;
    history.forEach((item: NutritionTargetSnapshot) => {
      const itemTime: number = NutritionDateUtils.getDayStartTime(item.dayKey);
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
    const targetTime: number = NutritionDateUtils.getDayStartTime(dayKey);
    if (Number.isNaN(targetTime)) return currentTarget;
    let matchedTarget: number = history.length === 0 ? currentTarget : defaultTarget;
    let matchedTime: number = -1;
    history.forEach((item: NutritionTargetSnapshot) => {
      const itemTime: number = NutritionDateUtils.getDayStartTime(item.dayKey);
      if (itemTime <= targetTime && itemTime >= matchedTime) {
        matchedTime = itemTime;
        matchedTarget = item.target;
      }
    });
    return matchedTarget;
  }
}
