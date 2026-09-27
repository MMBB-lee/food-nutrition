export interface FoodItem {
  id: number;
  foodCode: string;
  name: string;
  category: string;
  topCategory: string;
  emoji: string;
  edible: number;
  energyKCal: number;
  protein: number;
  fat: number;
  carbohydrate: number;
  dietaryFiber: number;
  cholesterol: number;
  vitaminA: number;
  thiamin: number;
  riboflavin: number;
  niacin: number;
  vitaminC: number;
  vitaminETotal: number;
  calcium: number;
  phosphorus: number;
  potassium: number;
  sodium: number;
  magnesium: number;
  iron: number;
  zinc: number;
  selenium: number;
  copper: number;
  manganese: number;
}

export interface FoodRecord {
  id: string;
  recordedAt: number;
  dayKey: string;
  mealIndex: number;
  foodCode: string;
  foodName: string;
  category: string;
  emoji: string;
  weight: number;
  energyKCal: number;
  protein: number;
  fat: number;
  carbohydrate: number;
  dietaryFiber: number;
  cholesterol: number;
  vitaminA: number;
  thiamin: number;
  riboflavin: number;
  niacin: number;
  vitaminC: number;
  vitaminETotal: number;
  calcium: number;
  phosphorus: number;
  potassium: number;
  sodium: number;
  magnesium: number;
  iron: number;
  zinc: number;
  selenium: number;
  copper: number;
  manganese: number;
}

export interface DailyNutritionSummary {
  calories: number;
  protein: number;
  fat: number;
  carbohydrate: number;
}

export interface NutritionHistoryDay {
  dayKey: string;
  calories: number;
  calorieTarget: number;
  carbohydrate: number;
  carbohydrateTarget: number;
  fat: number;
  fatTarget: number;
  protein: number;
  proteinTarget: number;
}

export interface NutritionTargetSnapshot {
  dayKey: string;
  target: number;
}
