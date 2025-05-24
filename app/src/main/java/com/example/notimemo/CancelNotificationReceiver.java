package com.example.notimemo;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.app.NotificationManager;

/**
 * 이 파일은 알림을 제거하는 역할을 하는 브로드캐스트 리시버.
 * 사용자가 알림에서 '지우기' 버튼을 눌렀을 때 이 리시버가 호출되어 알림을 제거함.
 */
public class CancelNotificationReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        manager.cancel(1);
    }
}
