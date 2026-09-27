import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { MealSettingsSnapshot, MealTimeSettings } from '../model/MealModels';
import { BREAKFAST_MINUTES_KEY, DINNER_MINUTES_KEY, LUNCH_MINUTES_KEY,
  NOTIFICATION_ENABLED_KEY, NutritionPreferences, PRIVACY_ACCEPTED_KEY,
  SETUP_COMPLETE_KEY } from './NutritionPreferences';

export class MealSettingsStore {
  private store: preferences.Preferences | undefined = undefined;

  async load(context: common.Context): Promise<MealSettingsSnapshot> {
    this.store = await NutritionPreferences.getStore(context);
    return {
      setupComplete: await this.store.get(SETUP_COMPLETE_KEY, false) as boolean,
      privacyAccepted: await this.store.get(PRIVACY_ACCEPTED_KEY, false) as boolean,
      breakfastMinutes: await this.store.get(BREAKFAST_MINUTES_KEY, 480) as number,
      lunchMinutes: await this.store.get(LUNCH_MINUTES_KEY, 720) as number,
      dinnerMinutes: await this.store.get(DINNER_MINUTES_KEY, 1080) as number,
      notificationEnabled: await this.store.get(NOTIFICATION_ENABLED_KEY, false) as boolean
    };
  }

  async acceptPrivacyConsent(): Promise<boolean> {
    return this.putAndFlush(PRIVACY_ACCEPTED_KEY, true, 'save privacy consent failed');
  }

  async saveMealTimes(times: MealTimeSettings, markSetupComplete: boolean = false): Promise<boolean> {
    if (this.store === undefined) return false;
    try {
      await this.store.put(BREAKFAST_MINUTES_KEY, times.breakfastMinutes);
      await this.store.put(LUNCH_MINUTES_KEY, times.lunchMinutes);
      await this.store.put(DINNER_MINUTES_KEY, times.dinnerMinutes);
      if (markSetupComplete) {
        await this.store.put(SETUP_COMPLETE_KEY, true);
      }
      await this.store.flush();
      return true;
    } catch (error) {
      console.error(`save meal settings failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  async saveNotificationEnabled(enabled: boolean): Promise<boolean> {
    return this.putAndFlush(NOTIFICATION_ENABLED_KEY, enabled, 'save notification setting failed');
  }

  private async putAndFlush(key: string, value: boolean, errorMessage: string): Promise<boolean> {
    if (this.store === undefined) return false;
    try {
      await this.store.put(key, value);
      await this.store.flush();
      return true;
    } catch (error) {
      console.error(`${errorMessage}: ${JSON.stringify(error)}`);
      return false;
    }
  }
}
