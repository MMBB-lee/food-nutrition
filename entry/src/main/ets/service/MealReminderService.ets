import { common } from '@kit.AbilityKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { MealTimeSettings } from '../model/MealModels';

const MEAL_REMINDER_SLOT_TYPE: notificationManager.SlotType =
  notificationManager.SlotType.SOCIAL_COMMUNICATION;

export enum NotificationVibrationStatus {
  UNAVAILABLE = -1,
  DISABLED = 0,
  ENABLED = 1
}

export class MealReminderService {
  static async isNotificationEnabled(): Promise<boolean> {
    return notificationManager.isNotificationEnabled();
  }

  static async requestEnableNotification(context: common.UIAbilityContext): Promise<void> {
    await notificationManager.requestEnableNotification(context);
  }

  static async openNotificationSettings(context: common.UIAbilityContext): Promise<void> {
    await notificationManager.openNotificationSettings(context);
  }

  static async cancelAll(): Promise<void> {
    try {
      await reminderAgentManager.cancelAllReminders();
    } catch (error) {
      console.error(`cancel meal notification failed: ${JSON.stringify(error)}`);
    }
  }

  static async schedule(times: MealTimeSettings): Promise<boolean> {
    try {
      await reminderAgentManager.addNotificationSlot({
        notificationType: MEAL_REMINDER_SLOT_TYPE,
        vibrationEnabled: true,
        vibrationValues: [400]
      });
      try {
        const reminderSlot: notificationManager.NotificationSlot = await notificationManager.getSlot(
          MEAL_REMINDER_SLOT_TYPE);
        console.info(`meal reminder slot state: ${JSON.stringify(reminderSlot)}`);
      } catch (slotError) {
        console.warn(`read meal reminder slot failed: ${JSON.stringify(slotError)}`);
      }

      const existingReminders: Array<reminderAgentManager.ReminderInfo> =
        await reminderAgentManager.getAllValidReminders();
      const retainedReminderIds: number[] = [];
      const mealMinutes: number[] = [times.breakfastMinutes, times.lunchMinutes, times.dinnerMinutes];
      const everyMonth: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
      const everyDayOfMonth: number[] = [
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
      ];
      for (let index: number = 0; index < mealMinutes.length; index++) {
        const reminderMinutes: number = (mealMinutes[index] - 20 + 1440) % 1440;
        const mealName: string = MealReminderService.getMealName(index);
        const firstReminderDate: Date = new Date();
        firstReminderDate.setHours(Math.floor(reminderMinutes / 60), reminderMinutes % 60, 0, 0);
        if (firstReminderDate.getTime() <= Date.now()) {
          firstReminderDate.setDate(firstReminderDate.getDate() + 1);
        }
        const reminderRequest: reminderAgentManager.ReminderRequestCalendar = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
          dateTime: {
            year: firstReminderDate.getFullYear(),
            month: firstReminderDate.getMonth() + 1,
            day: firstReminderDate.getDate(),
            hour: Math.floor(reminderMinutes / 60),
            minute: reminderMinutes % 60,
            second: 0
          },
          repeatMonths: everyMonth,
          repeatDays: everyDayOfMonth,
          title: '就餐提醒',
          content: `距离${mealName}还有20分钟`,
          expiredContent: `${mealName}时间快到了`,
          notificationId: 2001 + index,
          slotType: MEAL_REMINDER_SLOT_TYPE,
          actionButton: [{
            title: '删除',
            type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
          }],
          ringDuration: 1,
          tapDismissed: true,
          wantAgent: {
            pkgName: 'com.lmmbb.foodnutrition',
            abilityName: 'EntryAbility'
          },
          maxScreenWantAgent: {
            pkgName: 'com.lmmbb.foodnutrition',
            abilityName: 'EntryAbility'
          }
        };
        const existingReminder: reminderAgentManager.ReminderInfo | undefined = existingReminders.find(
          (info: reminderAgentManager.ReminderInfo) => info.reminderReq.notificationId === 2001 + index);
        if (existingReminder !== undefined) {
          try {
            await reminderAgentManager.updateReminder(existingReminder.reminderId, reminderRequest);
            retainedReminderIds.push(existingReminder.reminderId);
          } catch (updateError) {
            console.warn(`update meal reminder failed, republish it: ${JSON.stringify(updateError)}`);
            const reminderId: number = await reminderAgentManager.publishReminder(reminderRequest);
            retainedReminderIds.push(reminderId);
          }
        } else {
          const reminderId: number = await reminderAgentManager.publishReminder(reminderRequest);
          retainedReminderIds.push(reminderId);
        }
      }

      for (let index: number = 0; index < existingReminders.length; index++) {
        const info: reminderAgentManager.ReminderInfo = existingReminders[index];
        const notificationId: number | undefined = info.reminderReq.notificationId;
        const isMealReminder: boolean = notificationId !== undefined &&
          notificationId >= 2001 && notificationId <= 2003;
        if (isMealReminder && retainedReminderIds.indexOf(info.reminderId) < 0) {
          try {
            await reminderAgentManager.cancelReminder(info.reminderId);
          } catch (cancelError) {
            console.warn(`cancel stale meal reminder failed: ${JSON.stringify(cancelError)}`);
          }
        }
      }
      return true;
    } catch (error) {
      console.error(`schedule meal notification failed: ${JSON.stringify(error)}`);
      return false;
    }
  }

  static async getVibrationStatus(): Promise<NotificationVibrationStatus> {
    try {
      const settings = await notificationManager.getNotificationSetting();
      const slot: notificationManager.NotificationSlot = await notificationManager.getSlot(
        MEAL_REMINDER_SLOT_TYPE);
      if (!settings.vibrationEnabled || slot.enabled === false || slot.vibrationEnabled !== true) {
        return NotificationVibrationStatus.DISABLED;
      }
      console.info('meal reminder vibration is enabled by both system and notification slot');
      return NotificationVibrationStatus.ENABLED;
    } catch (error) {
      console.warn(`read notification vibration setting failed: ${JSON.stringify(error)}`);
      return NotificationVibrationStatus.UNAVAILABLE;
    }
  }

  private static getMealName(index: number): string {
    if (index === 0) return '早餐';
    if (index === 1) return '午餐';
    return '晚餐';
  }
}
