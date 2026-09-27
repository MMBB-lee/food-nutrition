import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export const PREFERENCES_NAME: string = 'meal_settings';
export const FOOD_RECORDS_KEY: string = 'foodRecords';
export const CALORIE_TARGET_KEY: string = 'calorieTarget';
export const CARBOHYDRATE_TARGET_KEY: string = 'carbohydrateTarget';
export const PROTEIN_TARGET_KEY: string = 'proteinTarget';
export const FAT_TARGET_KEY: string = 'fatTarget';
export const CALORIE_TARGET_HISTORY_KEY: string = 'calorieTargetHistory';
export const CARBOHYDRATE_TARGET_HISTORY_KEY: string = 'carbohydrateTargetHistory';
export const PROTEIN_TARGET_HISTORY_KEY: string = 'proteinTargetHistory';
export const FAT_TARGET_HISTORY_KEY: string = 'fatTargetHistory';
export const FIRST_USE_DAY_KEY: string = 'firstUseDayKey';
export const COMPLETION_DAY_KEY: string = 'completionDayKey';
export const NEXT_MEAL_INDEX_KEY: string = 'nextMealIndex';
export const BREAKFAST_MINUTES_KEY: string = 'breakfastMinutes';
export const LUNCH_MINUTES_KEY: string = 'lunchMinutes';
export const DINNER_MINUTES_KEY: string = 'dinnerMinutes';
export const SETUP_COMPLETE_KEY: string = 'setupComplete';
export const PRIVACY_ACCEPTED_KEY: string = 'privacyAccepted';
export const NOTIFICATION_ENABLED_KEY: string = 'notificationEnabled';

export class NutritionPreferences {
  static async getStore(context: common.Context): Promise<preferences.Preferences> {
    return preferences.getPreferences(context, { name: PREFERENCES_NAME });
  }
}
