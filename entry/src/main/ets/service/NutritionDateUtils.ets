export class NutritionDateUtils {
  static getDayKey(timestamp: number = Date.now()): string {
    const date: Date = new Date(timestamp);
    return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
  }

  static getDayStartTime(dayKey: string): number {
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
}
