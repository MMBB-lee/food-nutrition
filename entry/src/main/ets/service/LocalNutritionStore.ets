import { common } from '@kit.AbilityKit';
import { DailyNutritionSummary, FoodRecord, NutritionHistoryDay } from '../model/NutritionModels';
import { FoodRecordStore } from './FoodRecordStore';
import { MealProgressStore } from './MealProgressStore';
import { NutritionDateUtils } from './NutritionDateUtils';
import { NutritionTargetStore } from './NutritionTargetStore';

// Compatibility facade for callers outside this module. New page code should depend on
// the focused stores above so changes to one domain do not affect unrelated features.
export class LocalNutritionStore {
  static getDayKey(timestamp: number = Date.now()): string {
    return NutritionDateUtils.getDayKey(timestamp);
  }

  static async getAllFoodRecords(context: common.Context): Promise<FoodRecord[]> {
    return FoodRecordStore.getAll(context);
  }

  static async getFoodRecordsByDay(context: common.Context, dayKey: string): Promise<FoodRecord[]> {
    return FoodRecordStore.getByDay(context, dayKey);
  }

  static async addFoodRecord(context: common.Context, record: FoodRecord): Promise<void> {
    return FoodRecordStore.add(context, record);
  }

  static async deleteFoodRecord(context: common.Context, recordId: string): Promise<void> {
    return FoodRecordStore.delete(context, recordId);
  }

  static async updateFoodRecordWeight(context: common.Context, recordId: string,
    newWeight: number): Promise<void> {
    return FoodRecordStore.updateWeight(context, recordId, newWeight);
  }

  static summarize(records: FoodRecord[]): DailyNutritionSummary {
    return FoodRecordStore.summarize(records);
  }

  static async getFirstUseDayKey(context: common.Context): Promise<string> {
    return NutritionTargetStore.getFirstUseDayKey(context);
  }

  static async getCalorieTarget(context: common.Context): Promise<number> {
    return NutritionTargetStore.getCalorieTarget(context);
  }

  static async setCalorieTarget(context: common.Context, calories: number): Promise<void> {
    return NutritionTargetStore.setCalorieTarget(context, calories);
  }

  static async getCarbohydrateTarget(context: common.Context): Promise<number> {
    return NutritionTargetStore.getCarbohydrateTarget(context);
  }

  static async setCarbohydrateTarget(context: common.Context, grams: number): Promise<void> {
    return NutritionTargetStore.setCarbohydrateTarget(context, grams);
  }

  static async getProteinTarget(context: common.Context): Promise<number> {
    return NutritionTargetStore.getProteinTarget(context);
  }

  static async setProteinTarget(context: common.Context, grams: number): Promise<void> {
    return NutritionTargetStore.setProteinTarget(context, grams);
  }

  static async getFatTarget(context: common.Context): Promise<number> {
    return NutritionTargetStore.getFatTarget(context);
  }

  static async setFatTarget(context: common.Context, grams: number): Promise<void> {
    return NutritionTargetStore.setFatTarget(context, grams);
  }

  static async getNutritionHistory(context: common.Context, dayCount: number): Promise<NutritionHistoryDay[]> {
    return NutritionTargetStore.getHistory(context, dayCount);
  }

  static async saveMealProgress(context: common.Context, completionDayKey: string,
    nextMealIndex: number): Promise<void> {
    return MealProgressStore.save(context, completionDayKey, nextMealIndex);
  }

  static async getCompletionDayKey(context: common.Context): Promise<string> {
    return MealProgressStore.getCompletionDayKey(context);
  }

  static async getSavedNextMealIndex(context: common.Context): Promise<number> {
    return MealProgressStore.getSavedNextMealIndex(context);
  }

  static calculateAutomaticNextMealIndex(breakfastMinutes: number, lunchMinutes: number,
    dinnerMinutes: number, timestamp: number = Date.now()): number {
    return MealProgressStore.calculateAutomaticIndex(breakfastMinutes, lunchMinutes, dinnerMinutes, timestamp);
  }

  static async resolveMealProgress(context: common.Context, breakfastMinutes: number,
    lunchMinutes: number, dinnerMinutes: number, timestamp: number = Date.now()): Promise<number> {
    return MealProgressStore.resolve(context, breakfastMinutes, lunchMinutes, dinnerMinutes, timestamp);
  }

  static async resolveMealProgressFromSettings(context: common.Context,
    timestamp: number = Date.now()): Promise<number> {
    return MealProgressStore.resolveFromSettings(context, timestamp);
  }
}
