export interface MealTimeSettings {
  breakfastMinutes: number;
  lunchMinutes: number;
  dinnerMinutes: number;
}

export interface MealSettingsSnapshot extends MealTimeSettings {
  setupComplete: boolean;
  privacyAccepted: boolean;
  notificationEnabled: boolean;
}
