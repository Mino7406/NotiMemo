package com.example.notimemo;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;

/**
 * 이파일은 알림 영역에 메모를 고정하는 서비스.
 * 사용자가 앱을 종료해도 메모가 고정된 상태로 유지되며,
 * 알림에는 '지우기' 버튼도 포함되어 있음.
 */
public class NotiMemoService extends Service {

    private static final String CHANNEL_ID = "notimemo_channel";

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // MainActivity에서 전달받은 메모 텍스트 추출
        String memo = intent.getStringExtra("memo");

        // 알림 채널 생성 (Android 8.0 이상에서 필요)
        createNotificationChannel();

        // 알림 생성
        Notification notification = buildNotification(memo);

        // Foreground 서비스 시작
        startForeground(1, notification);

        return START_NOT_STICKY;
    }

    //알림 객체를 생성하는 함수
    private Notification buildNotification(String memo) {
        // 알림 클릭 시 앱의 MainActivity로 이동
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
                this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE
        );

        // '지우기' 액션 클릭 시 브로드캐스트 리시버 실행
        Intent cancelIntent = new Intent(this, CancelNotificationReceiver.class);
        cancelIntent.setAction("ACTION_CANCEL_NOTIFICATION");
        PendingIntent cancelPendingIntent = PendingIntent.getBroadcast(
                this, 1, cancelIntent, PendingIntent.FLAG_IMMUTABLE
        );

        // 알림 구성
        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notify_white)
                .setContentTitle("\uD83D\uDCCC 작성된 메모")
                .setContentText(memo)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "지우기", cancelPendingIntent)
                .build();
    }

    //Android 8.0 이상에서 Foreground 알림을 위해 알림 채널 생성
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "NotiMemo Channel",
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    //바인딩 서비스가 아니므로 null 반환
    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
