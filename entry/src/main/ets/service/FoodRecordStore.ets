import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { DailyNutritionSummary, FoodRecord } from '../model/NutritionModels';
import { FOOD_RECORDS_KEY, NutritionPreferences } from './NutritionPreferences';

export class FoodRecordStore {
  static async getAll(context: common.Context): Promise<FoodRecord[]> {
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
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

  static async getByDay(context: common.Context, dayKey: string): Promise<FoodRecord[]> {
    const records: FoodRecord[] = await FoodRecordStore.getAll(context);
    return records.filter((record: FoodRecord) => record.dayKey === dayKey);
  }

  static async add(context: common.Context, record: FoodRecord): Promise<void> {
    const records: FoodRecord[] = await FoodRecordStore.getAll(context);
    const existing: FoodRecord | undefined = records.find(
      (item: FoodRecord) => FoodRecordStore.isSameMealFood(item, record));
    if (existing === undefined) {
      records.push(record);
    } else {
      for (let index: number = records.length - 1; index >= 0; index--) {
        const item: FoodRecord = records[index];
        if (item.id !== existing.id && FoodRecordStore.isSameMealFood(item, record)) {
          FoodRecordStore.merge(existing, item);
          records.splice(index, 1);
        }
      }
      FoodRecordStore.merge(existing, record);
    }
    await FoodRecordStore.save(context, records);
  }

  static async delete(context: common.Context, recordId: string): Promise<void> {
    const records: FoodRecord[] = await FoodRecordStore.getAll(context);
    const remainingRecords: FoodRecord[] = records.filter((record: FoodRecord) => record.id !== recordId);
    await FoodRecordStore.save(context, remainingRecords);
  }

  static async updateWeight(context: common.Context, recordId: string, newWeight: number): Promise<void> {
    const records: FoodRecord[] = await FoodRecordStore.getAll(context);
    const record: FoodRecord | undefined = records.find((item: FoodRecord) => item.id === recordId);
    if (record === undefined || record.weight <= 0) return;
    const ratio: number = newWeight / record.weight;
    record.weight = newWeight;
    record.energyKCal = Math.round(record.energyKCal * ratio);
    record.protein = FoodRecordStore.scale(record.protein, ratio);
    record.fat = FoodRecordStore.scale(record.fat, ratio);
    record.carbohydrate = FoodRecordStore.scale(record.carbohydrate, ratio);
    record.dietaryFiber = FoodRecordStore.scale(record.dietaryFiber, ratio);
    record.cholesterol = FoodRecordStore.scale(record.cholesterol, ratio);
    record.vitaminA = FoodRecordStore.scale(record.vitaminA, ratio);
    record.thiamin = FoodRecordStore.scale(record.thiamin, ratio);
    record.riboflavin = FoodRecordStore.scale(record.riboflavin, ratio);
    record.niacin = FoodRecordStore.scale(record.niacin, ratio);
    record.vitaminC = FoodRecordStore.scale(record.vitaminC, ratio);
    record.vitaminETotal = FoodRecordStore.scale(record.vitaminETotal, ratio);
    record.calcium = FoodRecordStore.scale(record.calcium, ratio);
    record.phosphorus = FoodRecordStore.scale(record.phosphorus, ratio);
    record.potassium = FoodRecordStore.scale(record.potassium, ratio);
    record.sodium = FoodRecordStore.scale(record.sodium, ratio);
    record.magnesium = FoodRecordStore.scale(record.magnesium, ratio);
    record.iron = FoodRecordStore.scale(record.iron, ratio);
    record.zinc = FoodRecordStore.scale(record.zinc, ratio);
    record.selenium = FoodRecordStore.scale(record.selenium, ratio);
    record.copper = FoodRecordStore.scale(record.copper, ratio);
    record.manganese = FoodRecordStore.scale(record.manganese, ratio);
    await FoodRecordStore.save(context, records);
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

  private static async save(context: common.Context, records: FoodRecord[]): Promise<void> {
    const store: preferences.Preferences = await NutritionPreferences.getStore(context);
    await store.put(FOOD_RECORDS_KEY, JSON.stringify(records));
    await store.flush();
  }

  private static isSameMealFood(existing: FoodRecord, incoming: FoodRecord): boolean {
    if (existing.dayKey !== incoming.dayKey || existing.mealIndex !== incoming.mealIndex) return false;
    if (incoming.foodCode.length > 0) return existing.foodCode === incoming.foodCode;
    return existing.foodName === incoming.foodName && existing.category === incoming.category;
  }

  private static addValue(first: number, second: number): number {
    return Math.round((first + second) * 10) / 10;
  }

  private static merge(target: FoodRecord, source: FoodRecord): void {
    target.weight = FoodRecordStore.addValue(target.weight, source.weight);
    target.energyKCal = Math.round(target.energyKCal + source.energyKCal);
    target.protein = FoodRecordStore.addValue(target.protein, source.protein);
    target.fat = FoodRecordStore.addValue(target.fat, source.fat);
    target.carbohydrate = FoodRecordStore.addValue(target.carbohydrate, source.carbohydrate);
    target.dietaryFiber = FoodRecordStore.addValue(target.dietaryFiber, source.dietaryFiber);
    target.cholesterol = FoodRecordStore.addValue(target.cholesterol, source.cholesterol);
    target.vitaminA = FoodRecordStore.addValue(target.vitaminA, source.vitaminA);
    target.thiamin = FoodRecordStore.addValue(target.thiamin, source.thiamin);
    target.riboflavin = FoodRecordStore.addValue(target.riboflavin, source.riboflavin);
    target.niacin = FoodRecordStore.addValue(target.niacin, source.niacin);
    target.vitaminC = FoodRecordStore.addValue(target.vitaminC, source.vitaminC);
    target.vitaminETotal = FoodRecordStore.addValue(target.vitaminETotal, source.vitaminETotal);
    target.calcium = FoodRecordStore.addValue(target.calcium, source.calcium);
    target.phosphorus = FoodRecordStore.addValue(target.phosphorus, source.phosphorus);
    target.potassium = FoodRecordStore.addValue(target.potassium, source.potassium);
    target.sodium = FoodRecordStore.addValue(target.sodium, source.sodium);
    target.magnesium = FoodRecordStore.addValue(target.magnesium, source.magnesium);
    target.iron = FoodRecordStore.addValue(target.iron, source.iron);
    target.zinc = FoodRecordStore.addValue(target.zinc, source.zinc);
    target.selenium = FoodRecordStore.addValue(target.selenium, source.selenium);
    target.copper = FoodRecordStore.addValue(target.copper, source.copper);
    target.manganese = FoodRecordStore.addValue(target.manganese, source.manganese);
  }

  private static scale(value: number, ratio: number): number {
    return Math.round(value * ratio * 10) / 10;
  }
}
