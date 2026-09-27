import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { NutritionDateUtils } from './NutritionDateUtils';
import { BREAKFAST_MINUTES_KEY, COMPLETION_DAY_KEY, DINNER_MINUTES_KEY,
  LUNCH_MINUTES_KEY, NEXT_MEAL_INDEX_KEY, NutritionPreferences } from './NutritionPreferences';

export class MealProgressStore {
  static async save(context: common.Context, completionDayKey: string, nextMealIndex: number): Promise<void> {
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
    await store.put(COMPLETION_DAY_KEY, completionDayKey);
    await store.put(NEXT_MEAL_INDEX_KEY, nextMealIndex);
    await store.flush();
  }

  static async getCompletionDayKey(context: common.Context): Promise<string> {
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
    return await store.get(COMPLETION_DAY_KEY, '') as string;
  }

  static async getSavedNextMealIndex(context: common.Context): Promise<number> {
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
    return await store.get(NEXT_MEAL_INDEX_KEY, -1) as number;
  }

  static calculateAutomaticIndex(breakfastMinutes: number, lunchMinutes: number,
    dinnerMinutes: number, timestamp: number = Date.now()): number {
    const now: Date = new Date(timestamp);
    const currentMinutes: number = now.getHours() * 60 + now.getMinutes();
    if (currentMinutes > dinnerMinutes + 60) return 3;
    if (currentMinutes > lunchMinutes + 60) return 2;
    if (currentMinutes > breakfastMinutes + 60) return 1;
    return 0;
  }

  static async resolve(context: common.Context, breakfastMinutes: number,
    lunchMinutes: number, dinnerMinutes: number, timestamp: number = Date.now()): Promise<number> {
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
    const today: string = NutritionDateUtils.getDayKey(timestamp);
    const savedDay: string = await store.get(COMPLETION_DAY_KEY, '') as string;
    const savedIndex: number = await store.get(NEXT_MEAL_INDEX_KEY, -1) as number;
    const manualIndex: number = savedDay === today ? Math.max(0, Math.min(3, savedIndex)) : 0;
    const automaticIndex: number = MealProgressStore.calculateAutomaticIndex(
      breakfastMinutes, lunchMinutes, dinnerMinutes, timestamp);
    const resolvedIndex: number = Math.max(manualIndex, automaticIndex);
    if (savedDay !== today || savedIndex !== resolvedIndex) {
      await store.put(COMPLETION_DAY_KEY, today);
      await store.put(NEXT_MEAL_INDEX_KEY, resolvedIndex);
      await store.flush();
    }
    return resolvedIndex;
  }

  static async resolveFromSettings(context: common.Context, timestamp: number = Date.now()): Promise<number> {
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
    const breakfastMinutes: number = await store.get(BREAKFAST_MINUTES_KEY, 480) as number;
    const lunchMinutes: number = await store.get(LUNCH_MINUTES_KEY, 720) as number;
    const dinnerMinutes: number = await store.get(DINNER_MINUTES_KEY, 1080) as number;
    return MealProgressStore.resolve(context, breakfastMinutes, lunchMinutes, dinnerMinutes, timestamp);
  }
}
